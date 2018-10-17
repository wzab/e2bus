/*
 * e2bus.c - Driver for E2BUS control protocol for FPGA based system
 * Copyright (C) 2018 by Wojciech M. Zabolotny
 * Institute of Electronic Systems, Warsaw University of Technology
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 * Additionally I (Wojciech Zabolotny) allow you to include this header file
 * to compile your closed source applications (however yo should check, that
 * license terms of other include files used by this one allow you to do it...).
 */

#include "e2bus.h"
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/wait.h>
#include <linux/poll.h>
#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/fs.h>
#include <linux/init.h>
#include <linux/netdevice.h>
#include <linux/uaccess.h>
#include <linux/vmalloc.h>
MODULE_LICENSE("GPL");
#define SUCCESS 0
#define DEVICE_NAME "e2bus_dev"
#define BUF_LEN 100

static int max_slaves = 4;
module_param(max_slaves,int,0);
MODULE_PARM_DESC(max_slaves,"Maximum number of slave FPGA devices serviced by the system.");

static int proto_registered = 0; //Was the protocol registred? Should be deregistered at exit?

typedef struct {
    uint8_t cmd_fnum;
    uint16_t frnum; //number of the frame
    uint8_t * buf; //Pointer to the copy of skb with response data
    int pos; //Start position of the response data
    int len; //Length of the response data
    unsigned int confirm : 1;
    atomic_t filled;
    unsigned int last : 1;
    spinlock_t lock;
} resp_slot;


typedef struct {
    atomic_t filled;
    unsigned int confirmed : 1;
    unsigned int completed : 1;
    //fields describing the buffer obtained by get_user_pages
    int nr_pages;
    struct page ** pages;
    void * vbuf; //obtained via vmap
    uint8_t * rbuf; //buffer for responses with offset
    int max_resp_len;
    int resp_len;
    //other parameters
    uint16_t cmd_num;
    uint8_t * buf; //Buffer for commands
    int len;
    uint32_t status_and_pos;
    spinlock_t lock;
} cmd_slot;
/*
 * How we should connect our driver with a device?
 * Each client may use different device.
 * It should be defined after the device is open.
 * So it should depend od "file" object.
 */
typedef struct {
    unsigned char mac[ETH_ALEN];
    resp_slot * resp_slots;
    struct net_device *netdev;
    char active;
    uint8_t irq;
    spinlock_t irq_lock;
    struct device *dev;
    cmd_slot * cmd_slots;
    wait_queue_head_t wait_irq_queue;
    wait_queue_head_t wait_resp_queue;
    int next_cmd_slot; //For round-robin scheduling
    unsigned int is_open : 1;
    uint16_t cmd_num; //Sequential number of the command frame
    uint16_t cmd_num_to_receive; //Sequential number of the next command to receive
    uint16_t resp_cmd_num; //Number of the slot for which we await response.
    uint16_t resp_num; //Sequential number of the reponse frame
    struct tasklet_struct send_task;
    struct tasklet_struct resp_task;
    struct hrtimer send_timer;
} slave_data;


static int e2b_proto_rcv(struct sk_buff *skb, struct net_device *dev,
                         struct packet_type *pt, struct net_device *orig_dev);
static void send_spec_cmd(struct net_device * netdev, int cmd, unsigned char * slave_mac);

static struct packet_type e2b_proto_pt __read_mostly = {
    .type = cpu_to_be16(E2B_PROTO_ID),
    .dev = NULL,
    .func = e2b_proto_rcv,
};

slave_data * slave_table = NULL;
DEFINE_RWLOCK(slave_table_lock); //Used to protect table of slaves

/* Prototypes */
static void cleanup_cmd_slot(cmd_slot * cs);
/*
 * Function send packet sends one packet for the appropriate slave
 */
static void send_packet(unsigned long sl_as_ul)
{
    //pr_alert("in send packet 0");
    slave_data *sl = (slave_data *) sl_as_ul;
    //If slave is not active any more, return immediately!
    if( ! sl->active ) return;
    struct sk_buff *newskb = NULL;
    char *my_data;
    int i;
    int pkt_len=0;
    char anything_to_send = 0;
    char any_unconfirmed = 0;
    struct net_device *netdev = sl->netdev;
    //pr_alert("in send packet 1");
    //First we should check if there is anything to send?
    newskb = alloc_skb(LL_RESERVED_SPACE(netdev) + E2B_MAX_PKTLEN, GFP_ATOMIC);
    skb_reserve(newskb, LL_RESERVED_SPACE(netdev));
    skb_reset_network_header(newskb);
    newskb->dev = netdev;
    newskb->protocol = htons(E2B_PROTO_ID);
    // Build the MAC header for the new packet
    // Here is shown how to build a packet:
    // http://lxr.linux.no/linux+*/net/ipv4/arp.c#L586
    my_data = skb_put(newskb, 2);
    // Put the protocol version id to the packet
    *(my_data++) = (E2B_PROTO_VER >> 8) & 0xff;
    *(my_data++) = (E2B_PROTO_VER & 0xff);
    pkt_len += 2;
    //pr_alert("in send packet 2");
    // If there are any response confirmations, send them!
    for(i=0; i<E2B_NUM_OF_RESP_SLOTS; i++) {
        spin_lock_bh(&sl->resp_slots[i].lock);
        if( sl->resp_slots[i].confirm ) {
            my_data = skb_put(newskb, 2);
            *(my_data++) = ((sl->resp_slots[i].frnum >> 8) & 0xff) | 0x80;
            *(my_data++) = sl->resp_slots[i].frnum & 0xff;
            pkt_len += 2;
            sl->resp_slots[i].confirm = 0;
            anything_to_send = 1;
        }
        spin_unlock_bh(&sl->resp_slots[i].lock);
    }
    // Now if necessary, put the list of the commands
    // But it should be done in a "round robin" way.
    // We remember the last transmitted command in last_cmd_frame (?)
    //pr_alert("in send packet 3");
    for(i=1; i<=E2B_NUM_OF_CMD_SLOTS; i++) {
        //translate i to the number of slot with round robin
        int j = ( i + sl->next_cmd_slot) & E2B_CMD_SLOTS_MASK;
        cmd_slot * cs = &sl->cmd_slots[j];
        spin_lock_bh(&cs->lock);
        if((atomic_read(&cs->filled)!=0) && (cs->confirmed==0)) {
            any_unconfirmed = 1;
            //Transmit the header of the command list
            my_data = skb_put(newskb, 4);
            * my_data++ = 0x5a;
            * my_data++ = ((cs->cmd_num >> 8) & 0xff);
            * my_data++ = (cs->cmd_num & 0xff);
            * my_data++ = 0;
            // transmit the list of the commands
            my_data = skb_put(newskb, cs->len);
            memcpy(my_data,cs->buf,cs->len);
            pkt_len += cs->len;
            //leave the loop
            sl->next_cmd_slot = j; // Update the round robin index
            anything_to_send = 1;
            spin_unlock_bh(&cs->lock);
            break;
        } else {
            spin_unlock_bh(&cs->lock);
        }
    }
    // If the packet is too short, add the trailer
    if(pkt_len < E2B_MIN_PKTLEN) {
        int trailer_length = E2B_MIN_PKTLEN - pkt_len;
        my_data = skb_put(newskb,trailer_length);
        memset(my_data,E2B_PACKET_FILL, trailer_length); //It should be
    }
    if(any_unconfirmed) {
        //Schedule retransmission of any unconfirmed packet
        hrtimer_start(&sl->send_timer,ns_to_ktime(10000),HRTIMER_MODE_REL);
    }
    if(anything_to_send) {
        //pr_alert("in send packet - try to send");
        // Now set the true length of the packet (is it needed?)
        if (dev_hard_header(newskb, netdev, E2B_PROTO_ID, &(sl->mac),
                            sl->netdev->dev_addr, newskb->len) < 0) {
            kfree_skb(newskb);
            return;
        }
        dev_queue_xmit(newskb);
    } else {
        //pr_alert("in send packet - nothing to send");
        kfree_skb(newskb);
    }
    return;
};

/*
* We don't know what will be the length of each response. Therefore
* we handle all responses sequentially. The responses received "in advance"
* are stored in response slots.
* The number of currently serviced command slot is kept in
*/
static void handle_responses(unsigned long sl_as_ul)
{
    slave_data *sl = (slave_data *) sl_as_ul;
#ifdef E2B_DEBUG
    pr_alert("in handle responses resp_num=%d",sl->resp_num);
#endif
    while(1) {
        uint16_t rfrnum = sl->resp_num;
        int rslot = rfrnum  & E2B_RESP_SLOTS_MASK;
        resp_slot * rs = &sl->resp_slots[rslot];
        if(atomic_read(&rs->filled)==0) {
            //No more responses to service, leave the loop
            break;
        }
        //If we are there, we should have received the required response packet
        //We can transfer it to the buffer.
        //Let's make sure, that this response comes to the right command slot
        if((sl->resp_cmd_num & 0xff) != (rs->cmd_fnum)) {
            pr_alert("protocol error! Reponse delivered to wrong command slot! %x, %x",sl->resp_cmd_num,rs->cmd_fnum);
            //Probably we should generate here the protocol error and require
            //restart of communication!?
        }
        //We find the matching command slot.
        int rcs = sl->resp_cmd_num & E2B_CMD_SLOTS_MASK;
        cmd_slot * cs = &sl->cmd_slots[rcs];
        //Check if we don't try to overwrite the buffer
        if((cs->resp_len + rs->len) > cs->max_resp_len) {
            pr_alert("protocol error! trying to store too much data");
            //We should mark it as an error!
            //Maybe I should accumulate errors in a kind of status flag?
        } else {
            //Now we can really copy the data
#ifdef E2B_DEBUG
            pr_alert("preparing copy of %d bytes from %lx to %lx",rs->len,(unsigned long)&rs->buf[rs->pos],(unsigned long)&cs->rbuf[cs->resp_len]);
#endif
            memcpy(&cs->rbuf[cs->resp_len],&rs->buf[rs->pos],rs->len);
        }
        cs->resp_len += rs->len;
        if(rs->last) {
#ifdef E2B_DEBUG
            pr_alert("last packet - entry");
#endif
            //Mark packet as completed!
            cs->status_and_pos = *(uint32_t *) &rs->buf[rs->pos + rs->len - 4];
            * (uint32_t *)cs->rbuf = cs->resp_len; //Store the length
            cs->completed = 1;
            //Increase the number of command for which we expect response
            sl->resp_cmd_num += 1;
            sl->resp_cmd_num &= 0x7fff; //Should it be parametrized?
            //Here we should wake up processes waiting for response
            //@!@ Here we could free the GUP mapping, if it is safe to do it in interrupt
            //However it is safer to move it to the ioctl.
            wake_up_interruptible(&sl->wait_resp_queue);
#ifdef E2B_DEBUG
            pr_alert("last packet - exit");
#endif
        }
        //The buffer is copied or ignored, so we can free it
        kfree(rs->buf);
        rs->buf = NULL;
        //Copying is done, so we can mark the buffer as serviced
        atomic_set(&rs->filled,0);
        //Increase the number of expected response
        sl->resp_num++;
        sl->resp_num &= 0x7fff;
    }
#ifdef E2B_DEBUG
    pr_alert("leaving handle responses, resp_num=%d",sl->resp_num);
#endif
}

// Timer function
enum hrtimer_restart send_timer_fn(struct hrtimer * htp)
{
    slave_data * sd = container_of(htp, slave_data, send_timer);
    if(sd->active)
        tasklet_hi_schedule(&sd->send_task);
    return HRTIMER_NORESTART;
}


static int e2b_proto_rcv(struct sk_buff *skb, struct net_device *dev,
                         struct packet_type *pt, struct net_device *orig_dev)
{
    struct ethhdr *rcv_hdr = NULL;
    slave_data * sl = NULL;
    unsigned char * tmp_buf = NULL;
    int pkt_len;
    int send_pkt = 0;
    int slot;
    int ns;
    int bc; //byte counter
    rcv_hdr = eth_hdr(skb);
    pkt_len = skb->len;
    // First we try to identify the sender so we search the table of active slaves
    // When we receive the packet, we don't know with which slave it is associated
    // Therefore we need to find the right slave. (to be copied from FADE)
    read_lock_bh(&slave_table_lock);
    for (ns=0; ns<max_slaves; ns++) {
#ifdef E2B_DEBUG
        printk("slv: %2.2x:%2.2x:%2.2x:%2.2x:%2.2x:%2.2x  act: %d\n",
               (int)slave_table[ns].mac[0],(int)slave_table[ns].mac[1],(int)slave_table[ns].mac[2],
               (int)slave_table[ns].mac[3],(int)slave_table[ns].mac[4],(int)slave_table[ns].mac[5],
               (int)slave_table[ns].active);
#endif
        if (
            (slave_table[ns].active!=0) &&
            (memcmp(slave_table[ns].mac,rcv_hdr->h_source, sizeof(slave_table[0].mac))==0)
        ) break;
    }
    read_unlock_bh(&slave_table_lock);
    if (unlikely(ns==max_slaves)) {
        pr_warn("Received packet from incorrect slave!\n");
        kfree_skb(skb);
        //We should silence the rough slave!
        send_spec_cmd(dev,1,rcv_hdr->h_source);
        return NET_RX_DROP;
    }
    sl = &slave_table[ns]; //To speed up access to the data describing state of the slave
    //We do not use jumbo frames, so it may be acceptable to copy the whole packet to the buffer...
    //Check the length
    if(pkt_len > E2B_MAX_PKTLEN) {
        //Should we report it somehow?
        kfree_skb(skb);
        return NET_RX_DROP  ;
    }
    //Allocate the temporary buffer for the packet
    tmp_buf = kmalloc(pkt_len, GFP_ATOMIC);
    if(tmp_buf == NULL) {
        goto error_drop;
    }
    //We copy the packet to avoid problems caused by its fragmentation
    //(if it is needed... maybe we can do it conditionally?)
    skb_copy_bits(skb,0,tmp_buf,pkt_len);
    //OK. The packet is copied, now we can free it and parse the copied contents.
    kfree_skb(skb);
    skb=NULL;
    bc=0;
    while(bc<pkt_len) {
        unsigned char c1 = tmp_buf[bc++];
        if (c1 & 0x80) {
            //This should be the command confirmation
            if(bc>=pkt_len) {
                //error - there is no second byte of confirmation
                //we should log it @!@ and either return or jump to error
                goto error_drop;
            } else {
                uint16_t conf_num = ((c1 & 0x7f) << 8) | tmp_buf[bc++];
                //We have the number of confirmed frame. Now mark it as confirmed
                int slot_number = conf_num & E2B_CMD_SLOTS_MASK;
                //We check if the number is correct
                spin_lock_bh(&sl->cmd_slots[slot_number].lock);
                if(conf_num == sl->cmd_slots[slot_number].cmd_num) {
                    //This is the right confirmation
                    sl->cmd_slots[slot_number].confirmed = 1;
                }
                spin_unlock_bh(&sl->cmd_slots[slot_number].lock);
            }
        } else if ( c1 == 0x59) {
            //This is the IRQ notification
            if(bc>=pkt_len) {
                //error - there is no second byte of confirmation
                //we should log it @!@ and either return or jump to error
                goto error_drop;
            } else {
                //Here we should read the IRQ flags and wakeup the notifier thread
                //On could suppose, that the IRQ flags should accumulate:
                // sl->irq |= tmp_buf[bc++];
                //However, due to the latency of IRQ handling, it will result
                //in multiple notifications about already serviced interrupts
                sl->irq |= tmp_buf[bc++];
                wake_up_interruptible(&sl->wait_irq_queue);
            }
        } else if ( c1 == 0x51) {
            //This is the end marker - no more contents
            goto exit_success;
        } else if ( c1 == 0x5a) {
            //Handling of the response will be done in the second loop.
            break;
        }
    }
    //If we got there, it is either the end of the packet or start of the
    //response part
    if(bc==pkt_len) {
        //It is the end of the packet
        goto exit_success;
    }
    //Here we should handle the response part
    //There is one problem. All other data are transmitted in big-endian format
    //However here, the Xilinx DPR RAM with width conversion puts the LSB to the first cell.
    //It would require special byte-swapping in the HDL to fix it...
    //First we read the 8-bit CMD frame number
    //Then we read the 16-bit length, and later 16-bits with the response frame number
    //(for confirmation) and then with MSB informing if this is the last response.
    //So we need to get the 5-byte header.
    if(bc>=pkt_len-5) {
        dev_alert(sl->dev,"Wrong structure of the packet. Packet ends in the header");
        return NET_RX_DROP;
    }
    //Now we know, that we can access the header
    uint8_t cmd_fnum = tmp_buf[bc++];
    uint16_t sgm_len = tmp_buf[bc++];
    sgm_len |= (((uint16_t)tmp_buf[bc++]) << 8);
    uint16_t resp_fnum = tmp_buf[bc++];
    resp_fnum |= (((uint16_t)tmp_buf[bc++]) << 8);
    char last = resp_fnum & 0x8000 ? 1 : 0;
    resp_fnum &= 0x7fff;
    int sgm_pos = bc;
    //Lets check if we have the new part of response
    //
    // WARNING !!!
    // We should NOT confirm the response if it is not delivered yet!
    slot = resp_fnum & E2B_RESP_SLOTS_MASK;
    spin_lock_bh(&sl->resp_slots[slot].lock);
    uint16_t frame_in_slot = sl->resp_slots[slot].frnum;
    // What are the possibilities?
    // 1) It may be the right frame for that slot. Therefore we write
    //   the frame to the buffer.
    // 2) It may be a duplicate (e.g. previous confirmation was lost)
    //    Then we should resend the confirmation
    // 3) It may be a new frame for the same slot, but the previous
    //    was not consumed yet (so we ignore the frame, and it will be
    //    resent in the future).
    // 4) It may be
    //We should prepare transmission of confirmation
    //We need a function for comparisons modulo 2^15
    int cres = comp_mod_2_15(frame_in_slot,resp_fnum);
    if(cres==0) {
        //Frame in the slot is the same, we confirm it
        sl->resp_slots[slot].confirm = 1;
        if(sl->active)
	    send_pkt = 1;
            //tasklet_hi_schedule(&sl->send_task);
    } else if (cres>0) {
        //Frame in the slot is newer then the delivered
        //it should not happen! Protocol error?
        //we should log it
        dev_alert(sl->dev,"Outdated response frame received");
    } else if (cres<0) {
        //Frame in the slot is older than the delivered
        //we have to check if the old frame is consumed
        //If yes, we replace the old frame with the new one
        resp_slot * rs = &sl->resp_slots[slot];
        if(atomic_read(&rs->filled) == 0) {
            //If filled is not set, the buffer should be already freed
            //So we can put our buffer here
            rs->buf = tmp_buf;
            tmp_buf = NULL; //We don't own it any more
            rs->frnum=resp_fnum;
            rs->pos=sgm_pos;
            rs->len=sgm_len*4; //Length is expressed as the number of 32-bit words!
            rs->cmd_fnum=cmd_fnum;
            atomic_set(&rs->filled,1);
            rs->confirm=1; //Response delivered, we can confirm it!
            rs->last=last;
            if(sl->active) {
                //We trigger handling of responses
                tasklet_hi_schedule(&sl->resp_task);
                //We should trigger sending the packet
                send_pkt = 1;
                //tasklet_hi_schedule(&sl->send_task);
            }
            //New reponse delivered, so we can wake up the thread waiting for data
            //wake_up_interruptible(&sl->wait_resp_queue);
        }
    }
    spin_unlock_bh(&sl->resp_slots[slot].lock);
    if(send_pkt) send_packet((unsigned long) sl);
exit_success:
    if(skb)
        kfree_skb(skb);
    if(tmp_buf)
        kfree(tmp_buf);
    return NET_RX_SUCCESS;
error_drop:
    if (skb) {
        kfree_skb(skb);
        skb=NULL;
    }
    if (tmp_buf) {
        kfree(tmp_buf);
        tmp_buf = NULL;
    }
    return NET_RX_DROP;
}

dev_t e2b_dev = 0;
struct cdev *e2b_cdev = NULL;
static struct class *e2b_class = NULL;

static void cleanup_slave_data(slave_data * sd)
{
    int i;
    unsigned long flags;
    write_lock_irqsave(&slave_table_lock,flags);
    sd->active = 0;
    sd->is_open = 0;
    write_unlock_irqrestore(&slave_table_lock,flags);
    //We disable tasklets (synchronously!)
    //tasklet_disable(&sd->send_task);
    //tasklet_disable(&sd->resp_task);
    tasklet_kill(&sd->send_task);
    tasklet_kill(&sd->resp_task);
    //Slave data is inactive, so we can clear the list
    //of buffers without locking
    if(sd->cmd_slots) {
        for(i=0; i<E2B_NUM_OF_CMD_SLOTS; i++) {
            cleanup_cmd_slot(&sd->cmd_slots[i]);
        }
        kfree(sd->cmd_slots);
        sd->cmd_slots = NULL;
    }
    if(sd->resp_slots) {
        for(i=0; i<E2B_NUM_OF_RESP_SLOTS; i++) {
            if(sd->resp_slots[i].buf) {
                kfree(sd->resp_slots[i].buf);
                sd->resp_slots[i].buf = NULL;
            }
        }
        kfree(sd->resp_slots);
        sd->resp_slots = NULL;
    }
}

static int e2b_open(struct inode *inode, struct file *file)
{
    int i;
    int res = SUCCESS;
    slave_data * sd = NULL;
    unsigned long flags;
    i=iminor(inode)-MINOR(e2b_dev);
    if (i >= max_slaves) {
        printk(KERN_WARNING "Trying to access %s slave with too high minor number: %d\n",
               DEVICE_NAME, i);
        return -ENODEV;
    }
    read_lock_irqsave(&slave_table_lock,flags);
    sd = &slave_table[i];
    //Each device may be opened only once!
    if (sd->is_open) {
        return -EBUSY;
        read_unlock_irqrestore(&slave_table_lock,flags);
    }
    //Prepare slave_table for operation
    read_unlock_irqrestore(&slave_table_lock,flags);
    //Set the MAC address to 0
    memset(sd->mac,0,sizeof(sd->mac));
    sd->resp_slots = kzalloc(E2B_NUM_OF_RESP_SLOTS*sizeof(resp_slot), GFP_KERNEL);
    if(!sd->resp_slots) {
        res = -ENOMEM;
        goto open_error1;
    }
    for(i=0; i<E2B_NUM_OF_RESP_SLOTS; i++) {
        //Initialize response slot
        spin_lock_init(&sd->resp_slots[i].lock);
        sd->resp_slots[i].frnum = -1;
    }
    sd->cmd_slots =  kzalloc(E2B_NUM_OF_CMD_SLOTS*sizeof(cmd_slot), GFP_KERNEL);
    if(!sd->cmd_slots) {
        res = -ENOMEM;
        goto open_error1;
    }
    for(i=0; i<E2B_NUM_OF_CMD_SLOTS; i++) {
        //Initialize command slot
        spin_lock_init(&sd->cmd_slots[i].lock);
    }
    file->private_data=sd;
    sd->is_open = 1;
#ifdef E2B_DEBUG
    dev_alert(sd->dev,"Open completed!");
#endif
    return SUCCESS;
open_error1:
    cleanup_slave_data(sd);
    return res;
}

static void send_spec_cmd(struct net_device * netdev, int cmd, unsigned char * slave_mac)
{
    struct sk_buff *newskb = NULL;
    char *my_data;
    newskb = alloc_skb(LL_RESERVED_SPACE(netdev) + E2B_MAX_PKTLEN, GFP_ATOMIC);
    skb_reserve(newskb, LL_RESERVED_SPACE(netdev));
    skb_reset_network_header(newskb);
    newskb->dev = netdev;
    newskb->protocol = htons(E2B_PROTO_ID);
    // Build the MAC header for the new packet
    // Here is shown how to build a packet:
    // http://lxr.linux.no/linux+*/net/ipv4/arp.c#L586
    my_data = skb_put(newskb, 4);
    // Put the protocol version id to the packet
    *(my_data++) = (E2B_PROTO_VER >> 8) & 0xff;
    *(my_data++) = (E2B_PROTO_VER & 0xff);
    *(my_data++) = 0x5b;
    *(my_data++) = 0x1;
    // If the packet is too short, add the trailer
    if(newskb->len < E2B_MIN_PKTLEN) {
        int trailer_length = E2B_MIN_PKTLEN - newskb->len;
        my_data = skb_put(newskb,trailer_length);
        memset(my_data,E2B_PACKET_FILL, trailer_length); //It should be
    }
    if (dev_hard_header(newskb, netdev, E2B_PROTO_ID, slave_mac,
                        netdev->dev_addr, newskb->len) < 0) {
        kfree_skb(newskb);
    }
    dev_queue_xmit(newskb);
}
static int e2b_release(struct inode *inode, struct file *file)
{
    //We should stop the communication
    //@!@ Not implemented yet!
    //Then we can
    int i;
    //int res = SUCCESS;
    slave_data * sd = NULL;
#ifdef E2B_DEBUG
    pr_alert("Release 1");
#endif
    unsigned long flags;
    i=iminor(inode)-MINOR(e2b_dev);
    if (i >= max_slaves) {
        printk(KERN_WARNING "Trying to access %s slave with too high minor number: %d\n",
               DEVICE_NAME, i);
        return -ENODEV;
    }
    read_lock_irqsave(&slave_table_lock,flags);
    sd = &slave_table[i];
    read_unlock_irqrestore(&slave_table_lock,flags);
#ifdef E2B_DEBUG
    dev_alert(sd->dev,"Release 2");
#endif
    cleanup_slave_data(sd);
#ifdef E2B_DEBUG
    dev_alert(sd->dev,"Release 3");
#endif
    return SUCCESS;
}

/*
 * Utility functions to handle get_user_pages
*/
static int prepare_gup(struct e2b_v1_packet_to_send * pts, cmd_slot * cs)
{
    int i;
    int res = 0;
    struct page ** pages = NULL;
    long pinned = 0;
    void * vbuf = NULL;
    void * vresp = NULL;
    //Now make sure, that we will be able to write the response
    if (!access_ok(VERIFY_WRITE, pts->resp, pts->max_resp_len)) {
        pr_alert("GUP wrong access");
        res = -EFAULT;
        goto error_prep_gup_1;
    }
    //Prepare access via get_user_pages
    const unsigned long offset = ((unsigned long)pts->resp) & (PAGE_SIZE-1); //~PAGE_MASK;
    int nr_pages = DIV_ROUND_UP(offset + pts->max_resp_len, PAGE_SIZE);
#ifdef E2B_DEBUG
    pr_alert("offset=%lx, nr_pages=%x",offset,nr_pages);
#endif
    //Now we need to prepare the table of pages
    pages = (struct page **) kzalloc(sizeof(struct page)*nr_pages, GFP_KERNEL);
    if(!pages) {
        pr_alert("GUP can't alloc pages");
        res = -EFAULT;
        goto error_prep_gup_1;
    }
    //Then we may pin the pages
    pinned = get_user_pages_fast(((unsigned long)pts->resp) & PAGE_MASK,nr_pages,1,pages);
    if(pinned != nr_pages) {
        int i;
        //return all pages
        for(i=0; i<pinned; i++) {
            put_page(pages[i]);
        }
        kfree(pages);
        pr_alert("GUP can't pin pages");
        res = -EFAULT;
        goto error_prep_gup_1;
    }
    //Pages pinned, create the mapping
    vbuf = vmap(pages,nr_pages,VM_MAP, pgprot_writecombine(PAGE_KERNEL));
    vresp = vbuf + offset;
#ifdef E2B_DEBUG
    pr_alert("test vbuf %lx vresp %lx, offset=%lx",(unsigned long)vbuf,(unsigned long)vresp,offset);
#endif
    if(!vbuf) {
        pr_alert("GUP can't vmap pages");
        res = -EFAULT;
        goto error_prep_gup_1;
    }
    //Mapping is ready, copy its parameters to the command slot
    cs->nr_pages = nr_pages;
    cs->pages = pages;
    cs->vbuf = vbuf;
    cs->rbuf = vbuf+offset;
    cs->max_resp_len = pts->max_resp_len;
#ifdef E2B_DEBUG
    pr_alert("prepared mapping %lx with buffer %lx, offset=%lx",(unsigned long)cs->vbuf,(unsigned long)cs->rbuf,offset);
#endif
    return SUCCESS;
error_prep_gup_1:
    if(vbuf) {
        vunmap(vbuf);
        vbuf=NULL;
    }
    for(i=0; i<pinned; i++) {
        put_page(pages[i]);
    }
    kfree(pages);
    pages = NULL;
    res = -EFAULT;
    return res;
}

static void free_gup(cmd_slot * cs)
{
    int i;
    if(cs->vbuf) {
        vunmap(cs->vbuf);
        cs->vbuf = NULL;
        cs->rbuf = NULL;
    }
    if(cs->pages) {
        if(cs->nr_pages > 0) {
            for(i=0; i<cs->nr_pages; i++) {
                set_page_dirty(cs->pages[i]);
                put_page(cs->pages[i]);
            }
        }
        kfree(cs->pages);
        cs->pages = NULL;
    }
}

static void cleanup_cmd_slot(cmd_slot * cs)
{
    free_gup(cs);
    if(cs->buf) {
        vfree(cs->buf);
        cs->buf = NULL;
    }
    cs->confirmed = 0;
    cs-> completed = 0;
    atomic_set(&cs->filled,0);
}

//static __poll_t e2b_poll(struct file *filp, poll_table *wait)
static unsigned int e2b_poll(struct file *filp, poll_table *wait) // For kernel 4.15
{
    //Get access to the command slot, that is currently serviced
    slave_data *sd = filp->private_data;
    uint16_t cfrnum = sd->cmd_num_to_receive;
    int cslot = cfrnum  & E2B_CMD_SLOTS_MASK;
    cmd_slot * cs = &sd->cmd_slots[cslot];
    poll_wait(filp, &sd->wait_resp_queue, wait);
    //The condition below is the same as in RECEIVE
    if ((cs->completed != 0)) {
        return POLLIN | POLLRDNORM; // for kernel 4.15
        //return EPOLLIN | EPOLLRDNORM;
    }
    return 0;
}

long e2b_ioctl(struct file *filp, unsigned int cmd, unsigned long arg)
{
    int i;
#ifdef E2B_DEBUG
    pr_alert("I'm in IOCTL 0");
#endif
    slave_data *sd = filp->private_data;
#ifdef E2B_DEBUG
    dev_alert(sd->dev,"I'm in IOCTL");
#endif
    if (_IOC_TYPE(cmd) != E2B_V1_IOC_MAGIC) {
        dev_alert(sd->dev,"Wrong command:%x in E2B_IOC_OPEN",cmd);
        return -EINVAL;
    }
    switch (cmd) {
    case E2B_IOC_TEST: {
#ifdef E2B_DEBUG
        pr_alert("Alert bez dev z IOC_TEST");
        dev_alert(sd->dev,"Alert z dev z IOC_TEST");
#endif
        return SUCCESS;
    }
    case E2B_IOC_OPEN: {
        // Here we should set the connection to the particular device. Therefore we
        // need two arguments: the name of the network interface and the MAC address
        // of the target
        int res2;
        struct net_device *netdev;
        void *src = (void *)arg;
        struct e2b_v1_device_connection dc;
        if (!access_ok(VERIFY_READ, src, sizeof(dc))) {
            dev_alert(sd->dev,"Wrong permissions in E2B_IOC_OPEN");
            return -EFAULT;
        } else {
            res2 = __copy_from_user(&dc, src, sizeof(dc));
            if (res2) {
                dev_alert(sd->dev,"Couldn't copy dc in E2B_IOC_OPEN");
                return -EFAULT;
            }
        }
        /* Copy the MAC address */
        memcpy(&sd->mac, dc.dest_mac, ETH_ALEN);
        /* Get access to the device */
        netdev = dev_get_by_name(&init_net, dc.ifname);
        if (!netdev) {
            dev_alert(sd->dev,"Couldn't get network device:%s in E2B_IOC_OPEN",dc.ifname);
            return -ENODEV;
        }
        sd->netdev = netdev;
#ifdef E2B_DEBUG
        pr_alert("Found netdev: %p",netdev);
#endif
        // After the device is opened, it is desired
        // the FPGA core is reset, after that
        // the frame and response numbers should start
        // from 1
        sd->cmd_num = 1;
        sd->cmd_num_to_receive = 1;
        sd->resp_num = 0;
        sd->resp_cmd_num = 1;
#ifdef E2B_DEBUG
        pr_alert("Initializing tasklet and timer");
#endif
        tasklet_init(&sd->send_task,send_packet,(unsigned long) sd);
        tasklet_init(&sd->resp_task,handle_responses,(unsigned long) sd);
        hrtimer_init(&sd->send_timer,CLOCK_MONOTONIC, HRTIMER_MODE_REL);
        sd->send_timer.function = send_timer_fn;
#ifdef E2B_DEBUG
        pr_alert("Initilized tasklet and timer");
#endif
        sd->active = 1;
        //Send the reset package a few times
        for (i=0; i<10; i++) {
            send_spec_cmd(sd->netdev,1,sd->mac);
        }
        return SUCCESS;
    }
    case E2B_IOC_CLOSE: {
        /* Release the device */
        /* Clear the MAC address */
        //write_lock_bh(&slave_table_lock);
        sd->active = 0;
        tasklet_kill(&sd->send_task);
        tasklet_kill(&sd->resp_task);
        hrtimer_cancel(&sd->send_timer);
        //write_unlock_bh(&slave_table_lock);
        /* Find the net device */
        if (!sd->netdev)
            return -ENODEV;
        for (i=0; i<10; i++) {
            send_spec_cmd(sd->netdev,1, sd->mac);
        }
        memset(&sd->mac, 0, ETH_ALEN);
        dev_put(sd->netdev);
        sd->netdev = NULL;
        return SUCCESS;
    }
    case E2B_IOC_WAIT_IRQ: {
        long res;
        if(!sd->active) return -ENODEV;
        if(!sd->netdev) return -ENODEV;
        if(wait_event_interruptible(sd->wait_irq_queue,
                                    (sd->irq!=0) || (sd->active == 0))) {
            //We have received the signal
            return -ERESTARTSYS;
        }
        if(!sd->active) return -ENODEV;
        spin_lock_bh(&sd->irq_lock);
        res = (long) sd->irq;
        sd->irq = 0;
        spin_unlock_bh(&sd->irq_lock);
        return res;
    }
    case E2B_IOC_SEND_ASYNC: {
        //This IOCTL submits the packet for execution and returns immediately
        //We prepare the kernel-accessible structures describing our packet
        //It is not clear if the slave data should be spinlock protected
        //We never submit packets in parallel, but what about
        //the responses?
        long res,res2;
        void *src = (void *)arg;
        struct e2b_v1_packet_to_send pts;
        if (!access_ok(VERIFY_READ, src, sizeof(pts))) {
            return -EFAULT;
        } else {
            res2 = __copy_from_user(&pts, src, sizeof(pts));
            if (res2)
                return -EFAULT;
        }
#ifdef E2B_DEBUG
        pr_alert("copied packet");
#endif
        //mdelay(10);
        uint16_t cfrnum = sd->cmd_num;
        int cslot = cfrnum  & E2B_CMD_SLOTS_MASK;
        cmd_slot * cs = &sd->cmd_slots[cslot];
        //@!@ Here we must check if the slot is free!!!
        if (atomic_read(&cs->filled))
            return -EBUSY;
        //int resp_len = 0;
        //Prepare the command slot
        //spin_lock_bh(&cs->lock);
        //Free the previous buffer, if there was one
        if(cs->buf) {
            vfree(cs->buf);
            cs->buf = NULL;
        }
        cs->buf=vzalloc(pts.cmd_len);
        if(!cs->buf) {
            //spin_unlock_bh(&cs->lock);
            res = -ENOMEM;
            goto error_ioctl_async1;
        }
        //spin_unlock_bh(&cs->lock);
#ifdef E2B_DEBUG
        pr_alert("prepared slot");
#endif
        //mdelay(10);
        //Copy the command list to that buffer
        if (!access_ok(VERIFY_READ, pts.cmd, pts.cmd_len)) {
            res = -EFAULT;
            goto error_ioctl_async1;
        } else {
            res2 = __copy_from_user(cs->buf, pts.cmd, pts.cmd_len);
            if (res2) {
                res = -EFAULT;
                goto error_ioctl_async1;
            }
        }
        //prepare the buffer
        res = prepare_gup(&pts,cs); //@!@ What if prepare_gup fails?
        cs->resp_len = 4; //In the first word we store the length of the response!
        cs->status_and_pos = 0;
#ifdef E2B_DEBUG
        pr_alert("copied command");
#endif
        //mdelay(10);
        spin_lock_bh(&cs->lock); //Locking scheme must be corrected!
        cs->len = pts.cmd_len;
        cs->confirmed = 0;
        cs->completed = 0;
        cs->cmd_num = sd->cmd_num;
        atomic_set(&cs->filled,1);
        spin_unlock_bh(&cs->lock);
#ifdef E2B_DEBUG
        pr_alert("tested output");
#endif
        //mdelay(10);
        //After successfull submission, increase the command number
        sd->cmd_num += 1;
        sd->cmd_num &= 0x7fff; //Ensure mod 2^15 operation
        //Now we should trigger sending the commands
#ifdef E2B_DEBUG
        pr_alert("starting tasklet and timer");
#endif
        //mdelay(10);
        //send_packet((long) sd);
        tasklet_hi_schedule(&sd->send_task);
        //And start the timer for retransmission
        //hrtimer_start(&sd->send_timer,ns_to_ktime(100000),HRTIMER_MODE_REL);
#ifdef E2B_DEBUG
        pr_alert("started tasklet and timer");
#endif
        // @!@ TO BE DONE !!!
        //And finally we sleep interruptible waiting until the
        //package is serviced
        return cfrnum; //Return the assigned number of the slot
error_ioctl_async1:
        spin_lock_bh(&cs->lock);
        if(cs->buf) {
            vfree(cs->buf);
            cs->buf = NULL;
        }
        spin_unlock_bh(&cs->lock);
        return res;
    }
    return -EINVAL;

    case E2B_IOC_RECEIVE: {
        // In the RECEIVE we check if there is any new completed and not reported command set.
        // We must maintain the pointer to the next set to report.

        //Here we get information about availability of the response
        long res2=0;
        uint16_t cfrnum = sd->cmd_num_to_receive;
        int cslot = cfrnum  & E2B_CMD_SLOTS_MASK;
        cmd_slot * cs = &sd->cmd_slots[cslot];
        // @!@ TO BE DONE !!!
        //And finally we sleep interruptible waiting until the
        //package is serviced
        //If arg is not 0, we sleep waiting for the slot to be ready
        if(arg) {
            if(wait_event_interruptible(sd->wait_resp_queue,
                                        (atomic_read(&cs->filled)==0) || (cs->completed != 0))) {
                //We have received the signal
                //How we should clean up after that?
                return -ERESTARTSYS;
            }
        }
        // If filled was 0, return -EIO (@!@ - should be changed!)
        if(cs->completed == 0) return -EIO;
        //Now we browse all slots, to report the last completed
        while(cs->completed != 0) {
            atomic_set(&cs->filled,0);
            cs->completed  = 0;
            free_gup(cs);
            res2 = cfrnum;
            cfrnum = (cfrnum + 1) & 0x7ffff;
            sd->cmd_num_to_receive = cfrnum;
        }
        return res2;
    }

    case E2B_IOC_SEND_SYNC: {
        //This IOCTL submits the packet for execution and sleeps until it is executed
        //We prepare the kernel-accessible structures describing our packet
        //It is not clear if the slave data should be spinlock protected
        //We never submit packets in parallel, but what about
        //the responses?
        long res,res2;
        void *src = (void *)arg;
        struct e2b_v1_packet_to_send pts;
        if (!access_ok(VERIFY_READ, src, sizeof(pts))) {
            return -EFAULT;
        } else {
            res2 = __copy_from_user(&pts, src, sizeof(pts));
            if (res2)
                return -EFAULT;
        }
#ifdef E2B_DEBUG
        pr_alert("copied packet");
#endif
        //mdelay(10);
        uint16_t cfrnum = sd->cmd_num;
        int cslot = cfrnum  & E2B_CMD_SLOTS_MASK;
        cmd_slot * cs = &sd->cmd_slots[cslot];
        //@!@ Here we must check if the slot is free!!!
        if (atomic_read(&cs->filled))
            return -EBUSY;
        //int resp_len = 0;
        //Prepare the command slot
        //spin_lock_bh(&cs->lock);
        //Free the previous buffer, if there was one
        if(cs->buf) {
            vfree(cs->buf);
            cs->buf = NULL;
        }
        cs->buf=vzalloc(pts.cmd_len);
        if(!cs->buf) {
            //spin_unlock_bh(&cs->lock);
            res = -ENOMEM;
            goto error_ioctl_open1;
        }
        //spin_unlock_bh(&cs->lock);
#ifdef E2B_DEBUG
        pr_alert("prepared slot");
#endif
        //mdelay(10);
        //Copy the command list to that buffer
        if (!access_ok(VERIFY_READ, pts.cmd, pts.cmd_len)) {
            res = -EFAULT;
            goto error_ioctl_open1;
        } else {
            res2 = __copy_from_user(cs->buf, pts.cmd, pts.cmd_len);
            if (res2) {
                res = -EFAULT;
                goto error_ioctl_open1;
            }
        }
        //prepare the buffer
        res = prepare_gup(&pts,cs); //@!@ What if prepare_gup fails?
        cs->resp_len = 4; //In the first word we store the length of the response!
        cs->status_and_pos = 0;
#ifdef E2B_DEBUG
        pr_alert("copied command");
#endif
        //mdelay(10);
        spin_lock_bh(&cs->lock); //Locking scheme must be corrected!
        cs->len = pts.cmd_len;
        cs->confirmed = 0;
        cs->completed = 0;
        cs->cmd_num = sd->cmd_num;
        atomic_set(&cs->filled,1);
        spin_unlock_bh(&cs->lock);
#ifdef E2B_DEBUG
        pr_alert("tested output");
#endif
        //mdelay(10);
        //After successfull submission, increase the command number
        sd->cmd_num += 1;
        sd->cmd_num &= 0x7fff; //Ensure mod 2^15 operation
        //Now we should trigger sending the commands
#ifdef E2B_DEBUG
        pr_alert("starting tasklet and timer");
#endif
        //mdelay(10);
        //send_packet((long) sd);
        tasklet_hi_schedule(&sd->send_task);
        //And start the timer for retransmission
        //hrtimer_start(&sd->send_timer,ns_to_ktime(10000),HRTIMER_MODE_REL);
#ifdef E2B_DEBUG
        pr_alert("started tasklet and timer");
#endif
        // @!@ TO BE DONE !!!
        //And finally we sleep interruptible waiting until the
        //package is serviced
        //mdelay(10);
        if(wait_event_interruptible(sd->wait_resp_queue,cs->completed!=0)) {
            //We have received the signal
            //How we should clean up after that?
            return -ERESTARTSYS;
        }
        //Free the GUP
        free_gup(cs);
        //Get the result
        res = cs->resp_len;
        //Mark the slot as free
        atomic_set(&cs->filled,0);
        //Set the next slot to receive
        sd->cmd_num_to_receive = (cfrnum + 1) & 0x7fff;
        //I should also clear here somehow the
        //Stop the timer for retransmission
#ifdef E2B_DEBUG
        pr_alert("almost finished");
#endif
        //hrtimer_cancel(&sd->send_timer);
        return res;
error_ioctl_open1:
        spin_lock_bh(&cs->lock);
        if(cs->buf) {
            vfree(cs->buf);
            cs->buf = NULL;
        }
        spin_unlock_bh(&cs->lock);
        return res;
    }
    return -EINVAL;
    }
    return -EINVAL;
}

struct file_operations fops = {
    .owner = THIS_MODULE,
    .open = e2b_open,
    .poll = e2b_poll,
    .unlocked_ioctl = e2b_ioctl,
    .release = e2b_release,
};

static void e2b_cleanup(void)
{
    int i;
    printk(KERN_ALERT "E2B removed\n");
    /* Deregister protocol handler */
    if (proto_registered) {
        dev_remove_pack(&e2b_proto_pt);
        proto_registered = 0;
    };
    if(slave_table) {
        for(i=0; i<max_slaves; i++) {
            //Deinitialize slave
            cleanup_slave_data(&slave_table[i]);
        };
        //Free the table
        kfree(slave_table);
    };
    /* Remove device from the class */
    if (e2b_dev && e2b_class) {
        for(i=0; i<max_slaves; i++) {
            device_destroy(e2b_class, MKDEV(MAJOR(e2b_dev),MINOR(e2b_dev)+i));
        }
    }
    if (e2b_cdev)
        cdev_del(e2b_cdev);
    e2b_cdev = NULL;
    /* Zwalniamy numer urządzenia */
    unregister_chrdev_region(e2b_dev, max_slaves);
    /* Wyrejestrowujemy klasę */
    if (e2b_class) {
        class_destroy(e2b_class);
        e2b_class = NULL;
    }
}

static int e2b_init(void)
{
    int res;
    int i;
    printk(KERN_ALERT "Welcomr to e2bus driver\n");
    /* Create the table for slave devices */
    slave_table = kzalloc(sizeof(slave_data)*max_slaves, GFP_KERNEL);
    if (!slave_table) {
        res = -ENOMEM;
        goto err1;
    }
    /* Initialize the slave data */
    for(i=0; i<max_slaves; i++) {
        slave_data * sd = &slave_table[i];
        sd->active = 0;
        sd->dev = NULL;
        sd->netdev = NULL;
        init_waitqueue_head(&sd->wait_irq_queue);
        init_waitqueue_head(&sd->wait_resp_queue);
        //Initialize slave locks
        spin_lock_init(&sd->irq_lock);
    }
    /* Create the class for our device */
    e2b_class = class_create(THIS_MODULE, "e2bus_class");
    if (IS_ERR(e2b_class)) {
        printk(KERN_ERR "Error creating e2bus_class class.\n");
        res = PTR_ERR(e2b_class);
        goto err1;
    }
    /* Allocate the device number */
    res=alloc_chrdev_region(&e2b_dev, 0, max_slaves, DEVICE_NAME);
    if (res) {
        printk (KERN_ERR "Alocation of the device number for %s failed\n",
                DEVICE_NAME);
        goto err1;
    };
    /* Allocate the character device structure */
    e2b_cdev = cdev_alloc( );
    if (e2b_cdev == NULL) {
        printk (KERN_ERR "Allocation of cdev for %s failed\n",
                DEVICE_NAME);
        goto err1;
    }
    e2b_cdev->ops = &fops;
    e2b_cdev->owner = THIS_MODULE;
    /* Add the character device to the system */
    res=cdev_add(e2b_cdev, e2b_dev, max_slaves);
    if (res) {
        printk (KERN_ERR "Registration of the device number for %s failed\n",
                DEVICE_NAME);
        goto err1;
    }
    /* Create our devices in the system */
    for (i=0; i<max_slaves; i++) {
        slave_table[i].dev = device_create(e2b_class,NULL,MKDEV(MAJOR(e2b_dev),MINOR(e2b_dev)+i),NULL,"e2b_dev%d",i);
    }
    printk (KERN_ERR "%s The major device number is %d.\n",
            "Registration is a success.",
            MAJOR(e2b_dev));
    /* Connect our protocol handler */
    dev_add_pack(&e2b_proto_pt);
    proto_registered = 1;
    return SUCCESS;
err1:
    e2b_cleanup();
    return res;
}

module_init(e2b_init);
module_exit(e2b_cleanup);
