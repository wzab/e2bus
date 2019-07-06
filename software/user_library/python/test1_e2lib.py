import e2lib
e=e2lib.E2pkt()
r=[]
for i in range(0,20):
   r.append(e.write(0x80001200,[i+1,i+2,i+3,i+4,i+5],blen=5,dst_inc=1))
   r.append(e.read(0x80001200,blen=5,src_inc=2))
e.end_pkt()

