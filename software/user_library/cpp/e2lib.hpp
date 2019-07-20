#ifndef E2LIB_PUB_HPP
#define E2LIB_PUB_HPP

#include <zmq.hpp>
#include <memory>
#include <thread>
#include <future>
#include <unordered_map>

namespace E2B
{

const int MAX_PKT = 200;
const int PKT_HDR_LEN = 2; //2 words for the packet header

enum rmw_opers {
    OP_INC=0,
    OP_DEC=1,
    OP_ADD=2,
    OP_SUB=3,
    OP_AND=4,
    OP_OR=5,
    OP_XOR=6,
    OP_NOT=7,
};

enum rnt_tests {
    CMP_SLT=0,
    CMP_ULT=1,
    CMP_SGT=2,
    CMP_UGT=3,
    CMP_EQU=4,
    CMP_AND_EQU=5,
    CMP_OR_EQU=6,
};

///
/// Exceptions
///
class E2Bexception: public std::exception
{
    public:
        std::string expl;
        E2Bexception(const char* reason) : expl(reason) {};
        virtual const char* what() const throw()
        {
            return expl.data();
        }
};
///
/// The class representing a packet
///
class E2Pkt
{
    public:
        std::vector<uint32_t> commands {std::vector<uint32_t>(PKT_HDR_LEN,0)};
        std::unique_ptr<std::vector<uint32_t>> response;
        bool sent{false};
        // Fields used to handle reception of responses
        // Implementation based on https://en.cppreference.com/w/cpp/thread/condition_variable
        // Maybe it should be reimplemented using promise/future classes?
        bool answered{false};
        uint16_t status{0xffff};
        uint16_t pos{0xffff};
        std::condition_variable cv_ans;
        std::mutex m_ans;
        //
        int rlen{1}; //Reserve 1 word for length!
        int plen()
        {
            return commands.size()-PKT_HDR_LEN;
        };
        void add(uint32_t * dta, int dlen)
        {
            commands.insert(commands.end(),dta,dta+dlen);
        }
        void add(uint32_t dta)
        {
            commands.insert(commands.end(),dta);
        }
};

class E2CmdRef
{
    public:
        std::shared_ptr<E2Pkt> pkt;
        int cmd_start;
        int cmd_end;
        int res_start;
        int res_end;

        //Constructor
        E2CmdRef(std::shared_ptr<E2Pkt> a_pkt,
                 int a_cmd_start, int a_cmd_end,
                 int a_res_start, int a_res_end)
        {
            pkt = a_pkt;
            cmd_start = a_cmd_start;
            cmd_end = a_cmd_end;
            res_start = a_res_start;
            res_end = a_res_end;
        }
        //Read the response
        std::unique_ptr<std::vector<uint32_t>> response();
};
typedef std::unique_ptr<E2B::E2CmdRef> unique_cmdptr;
typedef std::unique_ptr<std::vector<uint32_t>> unique_resptr;
///
/// The main class responsible for connection with an E2Bus slave via E2Bus
///

///
/// The cur_pkt must be modified so, that it contains also the pointer
/// to the response buffer.
///
class E2BConn
{
    public:
        E2BConn( const std::string &conn); ///< Default constructor
        virtual ~E2BConn();
        //Methods for E2Bus accesses
        unique_cmdptr write(uint32_t address, uint32_t data, int dst_inc=0, int blen=1);
        unique_cmdptr write(uint32_t address, const std::vector<uint32_t> &data, int dst_inc=0, int blen=1);
        unique_cmdptr read(uint32_t address, int blen=1, int src_inc=0);
        unique_cmdptr rmw(uint32_t addr, rmw_opers oper, uint32_t dta = 0);
        unique_cmdptr rdntst(uint32_t addr, rnt_tests oper, uint32_t dta = 0, uint32_t mask = 0);
        unique_cmdptr mrdntst(uint32_t addr, rnt_tests oper, int repeat = 1, int delay = 1, uint32_t dta = 0, uint32_t mask = 0);
        unique_cmdptr errclr();
        unique_cmdptr endcmd();

        void end_pkt();

        void start(const std::string &conn);
        void e2g_com(const std::string conn);

    protected:
        //ZMQ related fields. Order is important, because it affects order of initilization and destruction!
        zmq::context_t ctx; ///< ZMQ context
        zmq::socket_t sock; ///< ZMQ socket for connection with the E2GW thread
        std::thread e2g_th; ///< Thread for communication with E2GW
        uint16_t pkt_id;
        // Map keeping the transmitted and not answered packets
        std::unordered_map<uint16_t,std::shared_ptr<E2Pkt>> pkts;

        // Buffer for assembling commands
        uint32_t cmds [MAX_PKT]; ///< Buffer for assembling of the command
        int cmd_len; ///< Number of words used in the buffer
        // Buffer for outgoing packet
        std::shared_ptr<E2Pkt> cur_pkt;
        //Methods
        std::unique_ptr<E2CmdRef> add_cmd(int rlen);
        inline void add_cmd_word(uint32_t cmd_word);
        inline void transmit_pkt();
        std::atomic_bool terminate {false};
};

}
#endif // E2LIB_PUB_HPP


