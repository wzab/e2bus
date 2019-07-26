import e2lib
import time
I2C_BASE=0
e2b=e2lib.E2pkt()

#e2b.errclr()
#e2b.end_pkt()
time.sleep(0.1)
for i in range(0,1000000):
  #We generate HUGE responses!
  r1=e2b.read(0x8,300)
  r2=e2b.read(0x9,300)
  e2b.end_pkt()
  v1=r1.read_values()
  v2=r2.read_values()
  print(i)

