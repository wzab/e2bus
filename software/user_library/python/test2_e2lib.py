import e2lib
e=e2lib.E2pkt()
#Write to the counter
r1=e.write(0x4e459943,0x2123)
r2=e.mrdntst(0x4e459943,e2lib.CMP_EQU,repeat=1023,delay=51,dta=0
e.end_pkt()
print(r2.read_values())
