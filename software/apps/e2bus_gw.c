#include <stdlib.h>
#include <sys/ioctl.h>
#include <fcntl.h>           /* For O_* constants */
#include <sys/stat.h>        /* For mode constants */
#include <unistd.h>
#include <stdio.h>
#include <string.h>
//struct sockaddr { int a; }; //for old Knoppix or Buildroot!
#include <assert.h>
#include <zmq.h>
#include <pthread.h>
#include <semaphore.h>
#include <endian.h>
#include "e2bus.h"


int fo;

struct e2b_v1_device_connection dc = {
    //.ifname = "eth0",
    //.ifname = "enx00e04c680185",
    //.ifname = "enp3s0f1",
    .ifname = "enp2s0",
    .dest_mac = "\x0e\x68\x61\x2d\xd4\x7e",
};
struct e2b_v1_packet_to_send pts;

typedef struct e2b_req {
    uint16_t id; // Request ID
    uint16_t len; // Length of the command part in bytes (4*len in words)
    uint32_t maxrlen; //Maximum length of the response in bytes
    uint32_t cmd[0]; //Vector with commands
} e2b_req_t;

typedef struct e2b_resp_obj e2b_resp_obj_t;

typedef struct e2b_resp {
    uint16_t id; //Frame ID
    uint16_t req_id; // Request ID
    //uint16_t status; // Status of the response
    uint32_t rlen; //Length of the response in bytes (4* len in words)
    uint32_t dta[0]; //Vector with response words
} e2b_resp_t;

typedef struct e2b_resp_obj {
    //The first part is used only internally
    e2b_resp_obj_t * prev;
    e2b_resp_obj_t * next;
    //This part will be transmitted (maybe it should be kept in a "substructure"?)
    e2b_resp_t resp;
} e2b_resp_obj_t;

//Request list pointers
e2b_resp_obj_t * volatile resp_head = NULL;
e2b_resp_obj_t * volatile resp_tail = NULL;
void * serve_irqs(void * sv);
void * serve_cmds(void * sv);
void *ctx = NULL;

sem_t queue_lock;

void main(int argc, char * argv[])
{
    pthread_t thr_irqs;
    pthread_t thr_cmds;
    int res;
    sem_init(&queue_lock,0,1);
    ctx=zmq_ctx_new ();
    assert (ctx);
    //Here we first connect to our device
    fo=open("/dev/e2b_dev0",O_RDWR);
    if(!fo) {
        perror("Can't open device");
        exit(1);
    }
    printf("Successfully open the device file\n");
    //return 0;
    //Test ioctl
    //We connect to the FPGA and initialize it...
    res = ioctl(fo,E2B_IOC_TEST,NULL);
    //return 0;
    //Connect to the device
    res = ioctl(fo,E2B_IOC_OPEN,&dc);
    printf("OPEN returns:%d\n",res);
    //Then we start both threads
    res = pthread_create(&thr_irqs,NULL,serve_irqs,NULL);
    if(res) {
        perror("I can't create the IRQ thread");
        exit(2);
    }
    res = pthread_create(&thr_cmds,NULL,serve_cmds,NULL);
    if(res) {
        perror("I can't create the CMD thread");
        exit(2);
    }
    //Finally we can wait for them?
    pthread_join(thr_irqs,NULL);
    pthread_join(thr_cmds,NULL);
}

void * serve_irqs(void * sv)
{
    int res;
    //return;
    /* function run in the thread handling the irqs*/
    /* Create ZMQ_STREAM socket */
    void *socket = zmq_socket (ctx, ZMQ_PUB);
    assert (socket);
    int rc = zmq_bind (socket, "tcp://0.0.0.0:56788");
    while (1) {
        uint8_t irqs;
        printf("Waiting for IRQ\n");
        res=ioctl(fo,E2B_IOC_WAIT_IRQ,0);
        //Send the message with IRQs
        irqs=res;
        zmq_send(socket,&irqs,sizeof(irqs),0);
    }
}

void * serve_cmds(void * sv)
{
    /* function run in the thread handling the commands */
    unsigned char rbuf[2000];
    unsigned char wbuf[2000];
    unsigned int mprio;
    uint16_t fr_num;
    //return;
    /* Create ZMQ_STREAM socket */
    void *socket = zmq_socket (ctx, ZMQ_PAIR);
    assert (socket);
    int rc = zmq_bind (socket, "tcp://0.0.0.0:56789");
    assert (rc == 0);
    size_t msize = 256;
    while (1) {
        /* Prepare for polling */
        zmq_pollitem_t pits[2];
        pits[0].socket = socket;
        pits[0].fd = 0;
        pits[0].events = ZMQ_POLLIN;
        pits[0].revents = 0;
        pits[1].socket = NULL;
        pits[1].fd = fo;
        pits[1].events = ZMQ_POLLIN;
        pits[1].revents = 0;
        int res = zmq_poll(pits,2,-1);
        if(res<0) perror("zmq_poll error");
        if(res > 0) {
            if(pits[0].revents) {
                /*  We have received an E2Bus request */
                sem_wait(&queue_lock);
                msize = zmq_recv (socket,rbuf,2000, 0);
                //Cast it to the e2b_req pointer
                e2b_req_t * e2req = (e2b_req_t *) rbuf;
                //Correct endianness (LE in the packet!)
                e2req->id = le16toh(e2req->id);
                e2req->len = le16toh(e2req->len);
                e2req->maxrlen = le32toh(e2req->maxrlen);
                //Commands are tranferred transparently
                // Verify if the length is correct (not yet @!@)
                //printf("received id=%d len=%d\n, maxrlen=%d, first three bytes: %x %x %x",e2req->id, e2req->len,
                //e2req->maxrlen, (int) e2req->cmd[0],(int) e2req->cmd[1],(int) e2req->cmd[2]);
                // Create the request object
                // Please remember, that we don't need to copy the command buffer.
                // It is copied by the driver!
                pts.cmd = (uint8_t *) &e2req->cmd[0];
                pts.cmd_len = e2req->len;
                // We allocate the buffer for the response
                e2b_resp_obj_t * e2resp = malloc(sizeof(e2b_resp_obj_t) + e2req->maxrlen);
                // @!@ Here we should make sure, that allocation was successful!
                if(!e2resp) {
                    // But what we can do if not? We should send NACK?
                    fprintf(stderr,"I can't allocate the buffer for the response\n");
                    sem_post(&queue_lock);
                    exit(10);
                }
                pts.resp = (uint8_t *) &e2resp->resp.dta[0]; // ! To be completed
                pts.max_resp_len = e2req->maxrlen;
                // Submit the request object
                {
                    int res = ioctl(fo,E2B_IOC_SEND_ASYNC,&pts);
                    if(res < 0) printf("IOC_ASYNC<0: %d\n",res);
                    fr_num = res;
                }
                // Write the assigned number to the response object
                e2resp->resp.id = fr_num;
                e2resp->resp.req_id = e2req->id;
                // Put the request object on the list
                // We need to replace the identifier with the one assigned
                // We add the request object to the list
                e2resp->prev = NULL;
                e2resp->next = NULL;
                if(resp_tail == NULL) {
                    resp_tail = e2resp;
                }
                if(resp_head) {
                    e2resp->prev = resp_head;
                    resp_head->next = e2resp;
                }
                resp_head = e2resp;
                //printf("submitted %d \n",fr_num);
                sem_post(&queue_lock);
                // Shouldn't we confirm acceptation of the object?
                //    zmq_send....
            }
            if(pits[1].revents) {
                /* We have certains reponses ready */
                sem_wait(&queue_lock);
                long r2 = ioctl(fo,E2B_IOC_RECEIVE,0);
                sem_post(&queue_lock);
                //printf("received:%d\n",r2);
                /* Now we can scan the list until we find the last serviced */
                while(1) {
                    //We should check that the list is not empty
                    //It shouldn't be, but it is better to make sure!
                    //We get the object from the list

                    uint32_t to_send;
                    sem_wait(&queue_lock);
                    e2b_resp_obj_t * e2resp = resp_tail;
                    sem_post(&queue_lock);
                    if(e2resp == NULL) {
                        //printf("Break due to empty list\n");
                        break; //No more elements in list (so head should be also NULL, who warrants that?)
                    }
                    //Now check if the number is OK
                    if(comp_mod_2_15(e2resp->resp.id,r2)>0) {
                        //printf("Will be serviced later\n");
                        break; //This element is not to be serviced now!
                    }
                    //printf("id: %d,",e2resp->resp.id);
                    //Here we process the element
                    //Extract the length from the first word
                    to_send = e2resp->resp.dta[0]; //Length is in bytes, it is stored by the driver in native endianness!!!
                    //Extract the status of the response
                    //e2resp->resp.status = le32toh(e2resp->resp.dta[e2resp->resp.rlen/4-1]); //The offset should be parametrized?
                    //We transmit the response
                    //First we correct the endianness
                    e2resp->resp.id = htole16(e2resp->resp.id);
                    e2resp->resp.req_id = htole16(e2resp->resp.req_id);
                    e2resp->resp.rlen = htole32(to_send);

                    msize=zmq_send(socket,&e2resp->resp, to_send+2*sizeof(uint16_t)+sizeof(uint32_t),0);
                    //Now we take it off the list
                    sem_wait(&queue_lock);
                    resp_tail = e2resp->next;
                    if(resp_tail) {
                        resp_tail->prev = NULL;
                    } else {
                        resp_head = NULL;
                    }
                    sem_post(&queue_lock);
                    //Now we can free the object
                    free(e2resp);
                }
            }
        }
    }
}


