/*
 * test.c
 *
 * Copyright 2018 Wojciech Zabołotny <wzab@wzab>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 *
 */


#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <stdint.h>
struct sockaddr { int a; }; //for old Knoppix or Buildroot!
#include "e2bus.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>

struct e2b_v1_device_connection dc = {
    .ifname = "br-lan",
    .dest_mac = "\xde\xad\xba\xbe\xbe\xef",
};
struct e2b_v1_packet_to_send pts;

int main(int argc, char **argv)
{
    int i;
    int nt; //number of the test
    int n_repeat=200; //number of repetitions
    int16_t fr1=0,fr2=0,fr3=0, fr4=0;
    long frcv,res2;
    uint8_t a[]="\x01\x12\xa0\x10" //2 zapisy
                "\xcc\x3c\x45\x2e"
                "\x45\x23\x43\x15"
                "\x45\x23\x43\x15" //koniec
                "\xff\x80\x80\x20" //255 odczytów
                "\x23\x99\x45\x11" //skąd odczyty
                "\xff\xff\xff\xef"; //END
    uint8_t b[2000];
    uint8_t a2[]="\x01\x12\xa0\x10" //2 zapisy
                 "\xcc\x3c\x45\x2e"
                 "\x45\x23\x43\x15"
                 "\x45\x23\x43\x15"
                 "\xc0\x80\x80\x20" //255 odczytów
                 "\x23\x99\x45\x11" //skąd odczyty
                 "\x00\x12\xa0\x10"//Zapis do countera
                 "\x43\x99\x45\x4e"
                 "\x23\x08\x00\x00"
                 "\x01\x10\x8c\x50" //Multiple read and compare
                 "\x43\x99\x45\x4e"
                 "\x00\x00\x00\x00"
                 "\xff\xff\xff\xef"; //END
    uint8_t b2[2000];
    uint8_t a3[]="\x01\x12\xa0\x10" //2 zapisy
                 "\xcc\x3c\x45\x2e"
                 "\x45\x23\x43\x15"
                 "\x45\x23\x43\x15"
                 "\xc0\x80\x80\x20" //255 odczytów
                 "\x23\x99\x45\x11" //skąd odczyty
                 "\x00\x12\xa0\x10"//Zapis do countera
                 "\x43\x99\x45\x4e"
                 "\x23\x08\x00\x00"
                 "\x01\x10\x98\x50" //Multiple read and compare
                 "\x43\x99\x45\x4e"
                 "\x00\x00\x00\x00"
                 "\xff\xff\xff\xef"; //END
    uint8_t b3[2000];
    uint8_t a4[]="\x01\x12\xa0\x10" //2 zapisy
                 "\xcc\x3c\x45\x2e"
                 "\x45\x23\x43\x15"
                 "\x45\x23\x43\x15"
                 "\xc0\x80\x80\x20" //255 odczytów
                 "\x23\x99\x45\x11" //skąd odczyty
                 "\x00\x12\xa0\x10"//Zapis do countera
                 "\x43\x99\x45\x4e"
                 "\x23\x08\x00\x00"
                 "\x01\x10\x98\x50" //Multiple read and compare
                 "\x43\x99\x45\x4e"
                 "\x00\x00\x00\x00"
                 "\xff\xff\xff\xef"; //END
    uint8_t b4[2000];
    if(argc>=1) {
      n_repeat=atoi(argv[1]);
    }
    printf("size a=%ld, size b=%ld\n",sizeof(a),sizeof(b));
    //return 1;
    int res;
    int fo=open("/dev/e2b_dev0",O_RDWR);
    if(!fo) {
        perror("Can't open device");
        exit(1);
    }
    printf("Successfully open the device file\n");
    //return 0;
    //Test ioctl
    res = ioctl(fo,E2B_IOC_TEST,NULL);
    //return 0;
    //Connect to the device
    res = ioctl(fo,E2B_IOC_OPEN,&dc);
    usleep(500000);
    printf("OPEN returns:%d\n",res);
    for(nt=0; nt<n_repeat; nt++) {
        printf("nt=%d\n",nt);
        //Clear the results
        memset(b,0,sizeof(b));
        memset(b2,0,sizeof(b2));
        memset(b3,0,sizeof(b3));
        //Now we prepare for transmission
        pts.cmd = a;
        pts.cmd_len = sizeof(a);
        pts.resp = b;
        pts.max_resp_len = sizeof(b);
        fr1 = ioctl(fo,E2B_IOC_SEND_ASYNC,&pts);
        printf("SEND1 returns:%d\n",(int)fr1);
        //Now we prepare for transmission
        pts.cmd = a2;
        pts.cmd_len = sizeof(a2);
        pts.resp = b2;
        pts.max_resp_len = sizeof(b2);
        fr2 = ioctl(fo,E2B_IOC_SEND_ASYNC,&pts);
        printf("SEND2 returns:%d\n",(int)fr2);
        //Now we prepare for transmission
        pts.cmd = a3;
        pts.cmd_len = sizeof(a3);
        pts.resp = b3;
        pts.max_resp_len = sizeof(b3);
        fr3 = ioctl(fo,E2B_IOC_SEND_ASYNC,&pts);
        printf("SEND3 returns:%d\n",(int)fr3);
        //Now we prepare for transmission
/*        pts.cmd = a4;
        pts.cmd_len = sizeof(a4);
        pts.resp = b4;
        pts.max_resp_len = sizeof(b4);
        fr4 = ioctl(fo,E2B_IOC_SEND_ASYNC,&pts);
        printf("SEND4 returns:%d\n",(int)fr4);
*/        printf("waiting for results\n");
        while(1) {
            long res=ioctl(fo,E2B_IOC_RECEIVE,1);
            if(res<0) {
                printf("RCV returns error:%ld\n",res);
                exit(res);
            }
            printf(".");
            if(comp_mod_2_15(res,fr3)>=0) break;
        }
        printf("Results from frame 1\n");
        res2 = *(uint32_t*) b;
        printf("len=%d\n",res2);
        for(i=res2-4; i<res2+8; i++) printf("%2.2x,",b[i]);
        printf("\n");
        printf("last 4 bytes:");
        for(i=res2-8; i<res2-4; i++) printf("%2.2x,",b[i]);
        printf("\n");
        printf("Results from frame 2\n");
        res2 = *(uint32_t*) b2;
        printf("len=%d\n",res2);
        for(i=res2-4; i<res2+8; i++) printf("%2.2x,",b2[i]);
        printf("\n");
        printf("last 4 bytes:");
        for(i=res2-8; i<res2-4; i++) printf("%2.2x,",b2[i]);
        printf("\n");
        printf("Results from frame 3\n");
        res2 = *(uint32_t*) b3;
        printf("len=%d\n",res2);
        for(i=res2-4; i<res2+8; i++) printf("%2.2x,",b3[i]);
        printf("\n");
        printf("last 4 bytes:");
        for(i=res2-8; i<res2-4; i++) printf("%2.2x,",b3[i]);
        printf("\n");/*
        printf("Results from frame 4\n");
        res2 = *(uint32_t*) b4;
        printf("len=%d\n",res2);
        for(i=res2-4; i<res2+8; i++) printf("%2.2x,",b4[i]);
        printf("\n");
        printf("last 4 bytes:");
        for(i=res2-8; i<res2-4; i++) printf("%2.2x,",b4[i]);
        printf("\n");*/
    }
    //Disconnect from the device
    res = ioctl(fo,E2B_IOC_CLOSE,NULL);
    printf("CLOSE returns:%d\n",res);
    return 0;
}

