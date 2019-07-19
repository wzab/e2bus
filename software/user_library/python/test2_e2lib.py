import e2lib
e=e2lib.E2pkt()
#Write to the counter
r1=e.read(0x8)
r2=e.read(0x9)
e.end_pkt()
v1=r1.read_values()
v2=r2.read_values()
print(hex(i) for i in v1)

