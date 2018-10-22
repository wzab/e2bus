import threading
import zmq
import struct
"""

"""
#Constants used to encode operations in RMW
OP_INC=0
OP_DEC=1
OP_ADD=2
OP_SUB=3
OP_AND=4
OP_OR=5
OP_XOR=6
OP_NOT=7

#Constants used to encode tests in READ&TEST and MULTIPLE_READ&TEST
CMP_SLT=0
CMP_ULT=1
CMP_SGT=2
CMP_UGT=3
CMP_EQU=4
CMP_AND_EQU=5
CMP_OR_EQU=6

PKT_MAX_LEN=20

#Dictionary that will store the packets
pkts = {}

#We connect to the transmit and receive thread...
#Initialize the context
ctx=zmq.Context()
#Prepare the socket for communication between the library and the transmission thread
l2t_s=ctx.socket(zmq.PAIR)
l2t_s.bind('inproc://src')

#Thread that transmits the packets
def transmission_proc(ctx,pkts):
  #Prepare the socket for communication with the E2Bus gateway
  e2g_s=ctx.socket(zmq.PAIR)
  e2g_s.connect('tcp://172.19.4.31:56789')
  #Prepare the socket for communication between the library and the transmission thread
  t2l_s=ctx.socket(zmq.PAIR)
  t2l_s.connect('inproc://src')
  p=zmq.Poller()
  p.register(e2g_s,flags=zmq.POLLIN)
  p.register(t2l_s,flags=zmq.POLLIN)
  while True:
    e=p.poll()
    for tp in e:
      if tp[0]==t2l_s:
        #We were given a new packet to transmit
        pkt_id=t2l_s.recv_pyobj()
        pkt=pkts[pkt_id]
        #We need to prepare a message for E2Bus gateway and transmit it
        m=struct.pack("<h",pkt_id)+struct.pack("<h",4*len(pkt.cmds))+\
          struct.pack("<L",4*pkt.rlen+16)+\
          struct.pack("<%dL"%len(pkt.cmds),*pkt.cmds)
        e2g_s.send(m)
        print(m)
        print("transmitted:" + str([hex(i) for i in m]))
        print("sent pkt_id="+str(pkt_id)+" len="+str(len(pkt.cmds))+" ")
      if tp[0]==e2g_s:
        #We have received the response vector!
        m=e2g_s.recv()
        print("received:" + str([hex(i) for i in m]))
        (m_id,m_stat,m_rlen) = struct.unpack("<h h L",m[0:8])
        m_cmd=struct.unpack("<%dL" % (m_rlen/4),m[8:])
        pkt=pkts.pop(m_id)
        pkt.response=m_cmd
        pkt.answered.set()
    

#Start the transmission thread
t=threading.Thread(target=transmission_proc, args=(ctx,pkts,))
t.daemon = True
t.start()

class E2pkt(object):
  # Inner classes
  class cmd_pkt(object):
    def __init__(self):
      self.sent = False
      self.answered = threading.Event()
      self.response = None
      self.cmds = []
      self.rlen = 1 # reserve one word for length!
    def __del__(self):
      print("pkt is deleted")
      
  class cmd_ref(object):
    def __init__(self, pkt, cmd_pos,resp_pos):
      self.pkt = pkt
      self.cmd_pos = cmd_pos
      self.resp_pos = resp_pos
    def read_values(self):
      #First wait, until response is delivered
      self.pkt.answered.wait()
      return self.pkt.response[self.resp_pos[0]:self.resp_pos[1]]
      
  def __init__(self):
    self.pkt_id=1 #We start from the packet with number 1
    self.cur_pkt = self.cmd_pkt()

  def add_cmd(self,cmds,rlen):
    """add_cmd adds the new command to the created packet.
    It the packet would be too long, the new packet is created.
    """
    if False:
      # Currently assembled packet - cur_pkt
      for wrd in cmds:
        line = ""
        for i in range(0,4):
          line +=  "\\x%2.2x" % (wrd & 0xff)
          wrd >>= 8
        print(line)
    #We check if the command is not too long
    if len(cmds) > PKT_MAX_LEN:
      raise Exception("Command is too long")
    #We check if the new command fits in the packet
    if len(self.cur_pkt.cmds) + len(cmds) > PKT_MAX_LEN:
      self.endcmd()
      self.transmit_pkt()
      #Start preparation of the new packet
      self.cur_pkt = self.cmd_pkt()
    cmd_start = len(self.cur_pkt.cmds)
    self.cur_pkt.cmds += cmds
    cmd_end = len(self.cur_pkt.cmds)
    cmd_rd_start = self.cur_pkt.rlen
    self.cur_pkt.rlen += rlen
    cmd_rd_end = self.cur_pkt.rlen
    #Now we return reference to the object describing
    #connection of the command with the transmitted packet,
    #command location and response location
    return self.cmd_ref(self.cur_pkt, (cmd_start, cmd_end), (cmd_rd_start, cmd_rd_end))
    
  def end_pkt(self):
    if(len(self.cur_pkt.cmds)>0):
      # Add END at the end of the buffer
      # (what if the packet has already the maximum length?)
      self.cur_pkt.cmds.append(0xEFffFFff)
      self.transmit_pkt()
      
  def transmit_pkt(self):
    if len(self.cur_pkt.cmds) > 0:
      #Store reference, so that we can find the response
      pkts[self.pkt_id] = self.cur_pkt
      self.cur_pkt.sent=True
      l2t_s.send_pyobj(self.pkt_id)
      self.pkt_id = (self.pkt_id + 1 ) & 0x7fff
      self.cur_pkt = self.cmd_pkt()

  def write(self,addr,dta,dst_inc=0,blen=1):
    """Write function.
    addr - initial write address
    dta - data to be written or vector of data to be written
    dst_inc - info if the destination address should be incremented or decremented
    """
    #First we check the arguments
    if not isinstance(dta,(list,tuple)):
       dta = [dta, ]
    src_inc = 0
    if len(dta) > 1:
      src_inc = 1
    if src_inc != 0:
        if blen != 1:
           if len(dta) != blen:
              raise Exception("Wrong length of data vector to be written")
    #Check the range of destination address increment
    if abs(dst_inc) >= (1<<11):
       raise Exception("Destination address increment outside the range")
    #Check the block length
    if (blen<1) or (blen > (1<<8)):
       raise Exception("Block length bigger than 255")
    #Now prepare the command words
    cmd=(1<<28) | (abs(dst_inc) << 8) | (blen - 1)
    if src_inc != 0:
       cmd |= (1<<23)
    if dst_inc > 0:
       cmd |= (1<<21)
    if dst_inc < 0:
       cmd |= (2<<21)
    if isinstance(dta,(list,tuple)):
       res=[cmd, addr, ]+list(dta)
    else:
       res=[cmd, addr, dta]
    # Here we need to add the command to the packet.
    # If it does not fit in the packet, we send the current packet and generate the next one
    rlen=0
    return self.add_cmd(res,rlen)

  def read(self,addr,blen=1,src_inc=0):
    """Read function.
    """
    #First we check the arguments
    if abs(src_inc) >= (1<<9):
       raise Exception("Source address increment outside the range")    
    if (blen < 1) or (blen > (1<<12)):
       raise Exception("Incorrect block length")    
    cmd=(2<<28) | (abs(src_inc) << 12) | (blen - 1)
    if src_inc > 0:
       cmd |= (1<<22)
    if src_inc < 0:
       cmd |= (2<<22)
    # Calculate the length of the response
    rlen = blen
    res=[cmd, addr]
    # Here we add the command to the packet, while generating
    return self.add_cmd(res,rlen)
    
  def rmw(self,addr,oper,dta=None):
    """ RMW function
    """
    #Check the operands
    if (oper < 0) or (oper > 7):
      raise Exception("Wrong operation code")
    cmd = (3 << 28) | (oper << 20)
    if oper in (OP_ADD,OP_SUB,OP_AND,OP_OR,OP_XOR):
      res = [cmd, addr, dta]
    else:
      res = [cmd, addr]
    rlen=0
    return self.add_cmd(res,rlen)
    
  def rdntst(self,addr,oper,dta,mask=None):
    """ RD&TST function
    """
    if (oper < 0) or (oper > 6):
      raise Exception("Wrong operation code")    
    cmd = (4 << 28) | (oper << 21)
    res = [cmd, addr, dta]
    if oper in (CMP_AND_EQU, CMP_OR_EQU):
      #We need mask
      res.append(mask)
    rlen=-1 #This command does not produce response, unless there is an error
    # In that case it produces one word of response
    return self.add_cmd(res,rlen)
    
  def mrdntst(self,addr,oper,repeat=1,delay=1,dta=None,mask=None):
    """ MRD&TST - Multiple Read & TST function
    """
    if (oper < 0) or (oper > 6):
      raise Exception("Wrong operation code")    
    if (repeat < 1) or (repeat > (1<<11)):
      raise Exception("Too big number of repetitions")    
    if (delay < 0) or (delay >= (1<<10)):
      raise Exception("Too big delay")    
    cmd = (5 << 28) | (oper << 21) | ((repeat-1) << 10) | delay
    res = [cmd, addr, dta]
    if oper in (CMP_AND_EQU, CMP_OR_EQU):
      #We need mask
      res.append(mask)
    rlen=1 
    return self.add_cmd(res,rlen)

  def endcmd(self):
    res = [0xefFFffFF,]
    rlen = 0    
    return self.add_cmd(res,rlen)
    
