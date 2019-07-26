import e2lib
import time
I2C_BASE=0
e2b=e2lib.E2pkt()
def i2c_init(wb_freq,i2c_freq):
  e2b.write(I2C_BASE+2,0)
  div=int(wb_freq/5.0/i2c_freq+0.5)
  e2b.write(I2C_BASE,div & 0xff)
  e2b.write(I2C_BASE+1,(div>>8) & 0xff)
  e2b.write(I2C_BASE+1,(div>>8) & 0xff)
  r=e2b.write(I2C_BASE+2,128)
  e2b.end_pkt()
  r.read_values()

def i2c_wr(adr,dta):
  e2b.write(I2C_BASE+3, 2*adr)
  e2b.write(I2C_BASE+4, 128 | 16)
  # Wait until bit 2 is cleared
  e2b.mrdntst(I2C_BASE+4,e2lib.CMP_AND_EQU,repeat=2048,delay=255,dta=0,mask=2)
  e2b.rdntst(I2C_BASE+4,e2lib.CMP_AND_EQU,dta=0,mask=128)
  e2b.write(I2C_BASE+3, dta)
  e2b.write(I2C_BASE+4, 64 | 16)
  # Wait until bit 2 is cleared
  e2b.mrdntst(I2C_BASE+4,e2lib.CMP_AND_EQU,repeat=2048,delay=255,dta=0,mask=2)
  r=e2b.rdntst(I2C_BASE+4,e2lib.CMP_AND_EQU,dta=0,mask=128)
  e2b.end_pkt()
  r.read_values()
  if r.pkt.status != 0:
      raise Exception("I2C WR: "+str([hex(i) for i in r.pkt.response]))

def i2c_rd(adr):
  e2b.write(I2C_BASE+3, 2*adr+1)
  e2b.write(I2C_BASE+4, 128 | 16)
  # Wait until bit 2 is cleared
  e2b.mrdntst(I2C_BASE+4,e2lib.CMP_AND_EQU,repeat=2048,delay=255,dta=0,mask=2)
  e2b.rdntst(I2C_BASE+4,e2lib.CMP_AND_EQU,dta=0,mask=128)
  e2b.write(I2C_BASE+4, 64 | 32 | 8)
  # Wait until bit 2 is cleared
  e2b.mrdntst(I2C_BASE+4,e2lib.CMP_AND_EQU,repeat=2048,delay=255,dta=0,mask=2)
  r=e2b.read(I2C_BASE+3)
  e2b.end_pkt()
  res=r.read_values()
  if r.pkt.status != 0:
      raise Exception("I2C RD: "+str([hex(i) for i in r.pkt.response]))
  return res[0]

#e2b.errclr()
#e2b.end_pkt()
time.sleep(0.1)
r1=e2b.read(0x8)
r2=e2b.read(0x9)
e2b.end_pkt()
v1=r1.read_values()
v2=r2.read_values()
print([hex(i) for i in v1])
# Should we run the stress test?
if True:
   for i in range(0,100000):
     i2c_wr(0x74,8)
     t=i2c_rd(0x5d)
     print i
