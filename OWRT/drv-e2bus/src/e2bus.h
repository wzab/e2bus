#ifndef _E2BUS_H_

/*
 * e2bus.h - header for E2BUS control protocol for FPGA based system
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
#include <linux/if_ether.h>
#include <linux/if.h>
//Structure describing the package to be send
struct e2b_v1_packet_to_send {
    uint8_t * cmd; // Buffer with command to be sent
    int cmd_len;
    uint8_t * resp; // Buffer for response
    int max_resp_len;
} __attribute__ ((__packed__));

struct e2b_v1_device_connection {
    char ifname[IFNAMSIZ];
    unsigned char dest_mac[ETH_ALEN];
} __attribute__ ((__packed__));


#define E2B_PROTO_ID 0xe2b5
#define E2B_PROTO_VER 0x0001
#define E2B_MAX_PKTLEN 1536
#define E2B_MIN_PKTLEN 100

//Value used to fill the packet after the cmd frame
#define E2B_PACKET_FILL 0x51


//#define E2B_DEBUG 1
// Definitions of constants
#define E2B_V1_IOC_MAGIC 0xe2

// Definitions of ioctl.s

#define E2B_IOC_OPEN    _IOR(E2B_V1_IOC_MAGIC,0x30, struct e2b_v1_device_connection)
#define E2B_IOC_SEND_SYNC   _IOR(E2B_V1_IOC_MAGIC,0x31, struct e2b_v1_packet_to_send)
#define E2B_IOC_SEND_ASYNC   _IOR(E2B_V1_IOC_MAGIC,0x32, struct e2b_v1_packet_to_send)
#define E2B_IOC_RECEIVE   _IOR(E2B_V1_IOC_MAGIC,0x33, struct e2b_v1_packet_to_send)
#define E2B_IOC_CLOSE   _IO(E2B_V1_IOC_MAGIC,0x34)
#define E2B_IOC_TEST   _IO(E2B_V1_IOC_MAGIC,0x35)
#define E2B_IOC_WAIT_IRQ   _IO(E2B_V1_IOC_MAGIC,0x36)
//#define E2B_V1_IOC_READPTRS   _IOR(E2B_V1_IOC_MAGIC,0x32,struct E2B_v1_buf_pointers)
//#define E2B_V1_IOC_WRITEPTRS      _IO(E2B_V1_IOC_MAGIC,0x33)
//#define E2B_V1_IOC_GETMAC        _IOW(E2B_V1_IOC_MAGIC,0x34,struct E2B_v1_slave)
//#define E2B_V1_IOC_STARTMAC       _IO(E2B_V1_IOC_MAGIC,0x35)
//#define E2B_V1_IOC_STOPMAC        _IO(E2B_V1_IOC_MAGIC,0x36)
//#define E2B_V1_IOC_FREEMAC        _IO(E2B_V1_IOC_MAGIC,0x37)
//#define E2B_V1_IOC_USERCMD        _IOWR(E2B_V1_IOC_MAGIC,0x38,struct E2B_v1_usercmd)

//Numbers below MUST be powers of 2!
#define E2B_NUM_OF_CMD_SLOTS (1<<4)
#define E2B_CMD_SLOTS_MASK (E2B_NUM_OF_CMD_SLOTS - 1)
#define E2B_NUM_OF_RESP_SLOTS (1<<4)
#define E2B_RESP_SLOTS_MASK (E2B_NUM_OF_RESP_SLOTS - 1)

#define E2B_RESP_SIZE 1024
//Parameters of the cyclical buffer (how many responses per slave do we keep?)
#define E2B_NUM_OF_RESP_IN_BUFFER 128

int comp_mod_2_15(uint16_t v1, uint16_t v2)
{
    uint16_t res = v1-v2;
    if ((res & 0x7fff) == 0) return 0;
    if ((res & 0x4000) != 0) return -1;
    else return 1;
}

#define _E2BUS_H_
#endif
