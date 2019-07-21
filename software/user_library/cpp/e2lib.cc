/*
 * e2lib.cc
 *
 * Copyright 2018 Wojciech Zabołotny <wzab01@gmail.com>
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


#include <e2lib.hpp>
#include <e2lib_priv.hpp>
#include <thread>
#include <unordered_map>
#include <memory>
#include <future>
#include <iostream>
#include <chrono>
namespace E2B
{
unique_resptr E2CmdRef::response()
{
    //When no response is received yet, wait for it
    // based on https://en.cppreference.com/w/cpp/thread/condition_variable
    {
        std::unique_lock<std::mutex> lk(pkt->m_ans);
        pkt->cv_ans.wait(lk, [&] {return pkt->answered;});
    }
    //Afterward create a vector (or span?)
    uint32_t * resp = pkt->response->data();
    //std::cout << "s:" << std::hex << resp << ",, "<< res_start << " to " << res_end << std::endl;
    //std::cout << "##" << resp[res_start] << "$$" << std::endl;
    return std::make_unique<std::vector<uint32_t>>(&resp[res_start],&resp[res_end]);
}

inline void E2BConn::add_cmd_word(uint32_t cmd_word)
{
    ///
    /// This function adds the next word to the currently assembled command
    /// it throws an exception if the command becomes too long
    ///
    if(cmd_len >= MAX_PKT) throw E2Bexception("command longer than MAX_PKT");
    cmds[cmd_len++] = htole32(cmd_word);
}

inline unique_cmdptr E2BConn::add_cmd(int rlen)
{
    ///
    /// This function adds the command assembled in the cmds buffer
    /// to the cur_pkt. If the cur_pkt would be too long, the previous
    /// packet is transmitted and creation of the new one is started.
    ///
    if(cmd_len > MAX_PKT) throw E2Bexception("Packet too long");
    if((cmd_len + cur_pkt->plen()) > MAX_PKT) {
        end_pkt(); //Optionally append the "END" command, transmit the packet and starte preparation of the new one.
    }
    int cmd_start = cur_pkt->plen();
    //Copy commands to the buffer
    cur_pkt->add(cmds,cmd_len);
    int cmd_end = cur_pkt->plen();
    int cmd_rd_start = cur_pkt->rlen;
    int cmd_rd_end = cur_pkt->rlen + abs(rlen);
    //Negative rlen means, that command generates output only in case of
    //an error!
    if (rlen > 0) cur_pkt->rlen += rlen;
    // Clear the buffer for the next command
    cmd_len = 0;
    //Now we create end return an object representing the command
    return std::make_unique<E2CmdRef>(cur_pkt,
                                      cmd_start,cmd_end,
                                      cmd_rd_start,cmd_rd_end);
}

void E2BConn::e2g_com(const std::string conn)
{
    //std::cout << "**" << conn.c_str() << "**" << std::endl;
    //Create socket for communication with the gateway
    zmq::socket_t e2g_sock(ctx,ZMQ_PAIR);
    e2g_sock.connect(conn.c_str());
    //Create socket for communication with the main thread
    zmq::socket_t mt_sock(ctx,ZMQ_PAIR);
    mt_sock.connect("inproc://src"); //Should be replaced with unique name!
    //Now we create the poller object
    zmq::pollitem_t poll_socks[2] = {
        {(void *) e2g_sock, 0, ZMQ_POLLIN, 0},
        {(void *) mt_sock, 0, ZMQ_POLLIN, 0},
    };
    //Now process messages from sockets
    while(terminate==false) {
        zmq::poll (&poll_socks[0],2,1000);
        if(poll_socks[0].revents & ZMQ_POLLIN) {
            zmq::message_t message;
            e2g_sock.recv(&message);
            //std::cout << "received 1!" << std::endl;
            //std::cout << "packet: ";
            //for (int i=0; i< message.size()/4; i++)
            //    std::cout << "," << std::hex << ((uint32_t *) message.data())[i];
            //std::cout << std::endl;
            //Here we receive the gateway response, and we glue it to the
            //appropriate packet
            //Read the packet id
            uint8_t * dptr = (uint8_t *) message.data();
            uint16_t frame_id = le16toh(*(uint16_t *)dptr);
            uint16_t pkt_id = le16toh(*(uint16_t *)(dptr + 2));
            uint32_t msglen = le32toh(*(uint32_t *)(dptr + 4));
            //Make sure that the length of the message is correct
            if(msglen > message.size()-8)
                throw E2Bexception("Incorrect message length");
            //Now we need to convert in place the received data
            uint32_t * d32ptr = (uint32_t *) (dptr+8);
            for(int i=0; i<msglen; i++) {
                d32ptr[i] = le32toh(d32ptr[i]);
            }
            std::shared_ptr<E2Pkt>  pkt(pkts[pkt_id]);
            pkt->status = le16toh(*(uint16_t *)(dptr+8+msglen-2));
            pkt->pos = le16toh(*(uint16_t *)(dptr+8+msglen-4));
            pkt->response = std::make_unique<std::vector<uint32_t>>((uint32_t *)(dptr+8),(uint32_t *)(dptr+8+msglen));
            {
                std::lock_guard<std::mutex> lk(pkt->m_ans);
                pkt->answered = true;
            }
            pkts.erase(pkt_id);
            pkt->cv_ans.notify_all();
        }
        if(poll_socks[1].revents & ZMQ_POLLIN) {
            zmq::message_t message;
            mt_sock.recv(&message);
            //std::cout << "received 2!" << std::endl;
            //Here we receive the message to be transmitted to the E2BGW
            //Now we can simply transmit it to the GW, however in the future
            //It may make sense to store it, until we know that the GW has processed
            //previous messages (if we know how many simultaneous messages it is able to handle,
            //we may count them all).
            //
            //@!@ Preparation of the message must be done in the main thread!!!!
            //std::cout << "packet: ";
            //for (int i=0; i< message.size()/4; i++)
            //    std::cout << "," << std::hex << ((uint32_t *) message.data())[i];
            //std::cout << std::endl;
            e2g_sock.send(message.data(),message.size());
            //std::cout << "sent 2!" << std::endl;
        }

    }
}

E2BConn::E2BConn(const std::string &conn) :
    ctx(1), sock(ctx,ZMQ_PAIR)
{
    //We create the internal socket server
    sock.bind("inproc://src"); //Should be replaced with unique name!
    //Allocate the buffer
    cur_pkt = std::make_shared<E2Pkt>();
    cmd_len = 0;
    pkt_id = 1;
}

void E2BConn::start(const std::string &conn)
{
    //Start the E2GW communication thread
    //The last argument MUST be called via std::ref. Otherwise we get a cryptic error:
    // error: static assertion failed: std::thread arguments must be invocable after conversion to rvalues
    //       static_assert( __is_invocable<typename decay<_Callable>::type,
    std::cout << ">>" << conn << "<<" << std::endl;
    e2g_th = std::thread(&E2BConn::e2g_com,this,conn);
}

void E2BConn::end_pkt()
{
    if(cur_pkt->plen() > 0) {
        //Here I'll need to add the test if the packet is not of maximum length!
        cur_pkt->add(htole32(0xefFFffFF));
        transmit_pkt();
    }
}

void E2BConn::transmit_pkt()
{
    if(cur_pkt->plen() > 0) {
        pkts[pkt_id] = cur_pkt;
        cur_pkt->sent = true;
        //Now we transfer the packet to the transmission procedure
        //We need to add the pkt_id (LE uint16_t),
        //the length in bytes (LE uint16_t),
        //and the length of response (LE uint32_t), which is
        //the expected size of response in bytes, increased by 8 (for status,
        // frame_id and length)
        //We have reserved the space for that header with PKT_HDR_LEN
        //std::cout << "pkt_len:" << cur_pkt->plen() << std::endl;
        cur_pkt->commands[0] = htole32(pkt_id | ( (4*cur_pkt->plen()) << 16));
        // We must add 8 bytes for additional information about the package
        cur_pkt->commands[1] = htole32(4*cur_pkt->rlen+8);
        //std::cout << "pkt to be sent: ";
        //for (int i=0; i< cur_pkt->commands.size(); i++)
        //    std::cout << "," << std::hex << (cur_pkt->commands.data())[i];
        //std::cout << std::endl;
        zmq::message_t msg(cur_pkt->commands.data(),4*cur_pkt->commands.size());
        sock.send(msg);
        pkt_id = (pkt_id + 1) & 0x7fff;
        cur_pkt = std::make_shared<E2Pkt>();
    }
}
E2BConn::~E2BConn()
{
    terminate=true;
    e2g_th.join();
}

///
/// Function, that checks if the current command overflows the buffer, and if yes,
/// sends it. Otherwise
///

unique_cmdptr E2BConn::write(uint32_t address, uint32_t data, int dst_inc, int blen)
{
    int src_inc = 0;
    int rlen = 0;
    uint32_t cmd = 0;
    //Length of the vector must be either 1 or equal to blen
    if (abs(dst_inc) >= (1<<11))
        throw E2Bexception("Destination address increment outside the range");
    if ((blen < 1) || (blen > (1<<8)))
        throw E2Bexception("Block length bigger than 255");
    cmd= (1<<28) | (abs(dst_inc) << 8) | (blen - 1);
    if(dst_inc > 0)
        cmd |= (1<<21);
    if(dst_inc < 0)
        cmd |= (2<<21);
    add_cmd_word(cmd);
    add_cmd_word(address);
    add_cmd_word(data);
    //Now we add the ready command
    return add_cmd(rlen);
}

unique_cmdptr E2BConn::write(uint32_t address, const std::vector<uint32_t> &data, int dst_inc, int blen)
{
    int src_inc = 0;
    int rlen = 0;
    uint32_t cmd = 0;
    //Length of the vector must be either 1 or equal to blen
    if (data.size() > 1)
        src_inc = 1;
    if(src_inc != 0) {
        if (data.size() != blen)
            throw E2Bexception("blen argument differs from the length of data vector");
    }
    if (abs(dst_inc) >= (1<<11))
        throw E2Bexception("Destination address increment outside the range");
    if ((blen < 1) || (blen > (1<<8)))
        throw E2Bexception("Block length bigger than 255");
    cmd= (1<<28) | (abs(dst_inc) << 8) | (blen - 1);
    if(src_inc != 0)
        cmd |= (1<<23);
    if(dst_inc > 0)
        cmd |= (1<<21);
    if(dst_inc < 0)
        cmd |= (2<<21);
    add_cmd_word(cmd);
    add_cmd_word(address);
    for(int i=0; i<data.size(); i++)
        add_cmd_word(data[i]);
    //Now we add the ready command
    return add_cmd(rlen);
}

unique_cmdptr E2BConn::read(uint32_t addr, int blen, int src_inc)
{
    int rlen = 0;
    uint32_t cmd = 0;
    //Length of the vector must be either 1 or equal to blen
    if (abs(src_inc) >= (1<<9))
        throw E2Bexception("Destination address increment outside the range");
    if ((blen < 1) || (blen > (1<<12)))
        throw E2Bexception("Block length bigger than 255");
    cmd= (2<<28) | (abs(src_inc) << 12) | (blen - 1);
    if(src_inc > 0)
        cmd |= (1<<22);
    if(src_inc < 0)
        cmd |= (2<<22);
    rlen = blen;
    add_cmd_word(cmd);
    add_cmd_word(addr);
    //Now we add the ready command
    return add_cmd(rlen);
}

unique_cmdptr E2BConn::rmw(uint32_t addr, rmw_opers oper, uint32_t dta)
{
    int rlen = 0;
    uint32_t cmd = 0;
    cmd= (3 << 28) | (((int) oper) << 20);
    add_cmd_word(cmd);
    add_cmd_word(addr);
    switch(oper) {
    case OP_ADD:
    case OP_SUB:
    case OP_AND:
    case OP_OR:
    case OP_XOR:
        add_cmd_word(dta);
    default:
        ;
    }
    rlen = 0;
    return add_cmd(rlen);
}

unique_cmdptr E2BConn::rdntst(uint32_t addr, rnt_tests oper, uint32_t dta, uint32_t mask)
{
    int rlen;
    uint32_t cmd = 0;
    cmd= (4 << 28) | (((int) oper) << 21);
    add_cmd_word(cmd);
    add_cmd_word(addr);
    switch(oper) {
    case CMP_AND_EQU:
    case CMP_OR_EQU:
        add_cmd_word(mask);
    default:
        add_cmd_word(dta);
    }
    rlen = -1;
    return add_cmd(rlen);
}

unique_cmdptr E2BConn::mrdntst(uint32_t addr, rnt_tests oper, int repeat, int delay, uint32_t dta, uint32_t mask)
{
    int rlen;
    uint32_t cmd = 0;
    if ((repeat < 1) || (repeat > (1 << 11)))
        throw E2Bexception("Too big number of repetitions");
    if ((delay < 0) || (delay >= (1<<10)))
        throw E2Bexception("Too big delay");
    cmd= (5 << 28) | (((int) oper) << 21) | ((repeat - 1) << 10) | delay;
    add_cmd_word(cmd);
    add_cmd_word(addr);
    switch(oper) {
    case CMP_AND_EQU:
    case CMP_OR_EQU:
        add_cmd_word(mask);
    default:
        add_cmd_word(dta);
    }
    rlen = 1;
    return add_cmd(rlen);
}

unique_cmdptr E2BConn::errclr()
{
    int rlen = 0;
    add_cmd_word(0xffFFffFF);
    return add_cmd(rlen);
}

unique_cmdptr E2BConn::endcmd()
{
    int rlen = 0;
    add_cmd_word(0xefFFffFF);
    return add_cmd(rlen);
}


}

//Operations on I2C

void i2c_init(E2B::E2BConn &cn, int i2c_base, int wb_freq, int i2c_freq)
{
    cn.write(i2c_base+2,0);
    int div=int(wb_freq/5/i2c_freq);
    cn.write(i2c_base,div & 0xff);
    cn.write(i2c_base+1,(div>>8) & 0xff);
    cn.write(i2c_base+1,(div>>8) & 0xff);
    E2B::unique_cmdptr r=cn.write(i2c_base+2,128);
    cn.end_pkt();
    r->response();
    return;
}

int i2c_rd(E2B::E2BConn &cn, int i2c_base, int adr)
{
    cn.write(i2c_base+3, 2*adr+1);
    cn.write(i2c_base+4, 128 | 16);
    // Wait until bit 2 is cleared
    cn.mrdntst(i2c_base+4, E2B::CMP_AND_EQU,2048,255,0,2);
    cn.rdntst(i2c_base+4, E2B::CMP_AND_EQU,0,128);
    cn.write(i2c_base+4, 64 | 32 | 8);
    // Wait until bit 2 is cleared
    E2B::unique_cmdptr mr1 = cn.mrdntst(i2c_base+4,E2B::CMP_AND_EQU,2048,255,0,2);
    E2B::unique_cmdptr r=cn.read(i2c_base+3);
    cn.end_pkt();
    E2B::unique_resptr res = r->response();
    if(r->pkt->status != 0) {
        throw E2B::E2Bexception("Error in I2C RD");
    }
    return (*res)[0];
}

void i2c_wr(E2B::E2BConn &cn, int i2c_base, int adr, int dta)
{
    cn.write(i2c_base+3, 2*adr);
    cn.write(i2c_base+4, 128 | 16);
    // Wait until bit 2 is cleared
    cn.mrdntst(i2c_base+4, E2B::CMP_AND_EQU,2048,255,0,2);
    cn.rdntst(i2c_base+4, E2B::CMP_AND_EQU,0,128);
    cn.write(i2c_base+3, dta);
    cn.write(i2c_base+4, 64 | 16);
    // Wait until bit 2 is cleared
    E2B::unique_cmdptr mr1 = cn.mrdntst(i2c_base+4,E2B::CMP_AND_EQU,2048,255,0,2);
    E2B::unique_cmdptr r = cn.rdntst(i2c_base+4, E2B::CMP_AND_EQU,0,128);
    cn.end_pkt();
    E2B::unique_resptr res = r->response();
    if(r->pkt->status != 0) {
        throw E2B::E2Bexception("Error in I2C RD");
    }
    return;
}

const int N_OF_TESTS = 100;
uint32_t test_results[N_OF_TESTS];

int main(int argc, char **argv)
{
    {
        E2B::E2BConn cn("tcp://127.0.0.1:56789");
        cn.start("tcp://127.0.0.1:56789");
        //cn.errclr();
        cn.end_pkt();
        for(int j=0; j<2; j++) {
            cn.write(10,std::vector<uint32_t> {10},1,1);
            std::unique_ptr<E2B::E2CmdRef> r1=cn.read(8,2,1);
            std::unique_ptr<E2B::E2CmdRef> r2=cn.read(8,3,1);
            cn.end_pkt();
            //Now print the read results
            std::cout << "Result: ";
            std::unique_ptr<std::vector<uint32_t>> rr1 = r1->response();
            for (int i=0; i< rr1->size(); i++)
                std::cout << "," << std::hex << (*rr1)[i] << ",";
            std::cout << std::endl;
            std::unique_ptr<std::vector<uint32_t>> rr2 = r2->response();
            for (int i=0; i< rr2->size(); i++)
                std::cout << "," << std::hex << (*rr2)[i] << ",";
            std::cout << std::endl;
        }
        i2c_init(cn,0,100000000,100000);
        i2c_wr(cn,0,0x74,0x8);
        std::cout << std::hex;
        auto start = std::chrono::high_resolution_clock::now();
        i2c_wr(cn,0,0x5d,0);
        for(int j=0; j<N_OF_TESTS; j++) {
            test_results[j]=i2c_rd(cn,0,0x5d);
            i2c_wr(cn,0,0x75,0);
        }
        auto finish = std::chrono::high_resolution_clock::now();
        std::chrono::duration<double> texec = finish-start;
        std::cout << "time:" << texec.count() << std::endl;
        for(int j=0; j<N_OF_TESTS; j++) {
            std::cout << j << ":" << test_results[j] << ",";
        }
        std::cout << std::endl;
    }
    return 0;
}


