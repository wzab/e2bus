OBJS1 =e2bus_gw.o 

EXECS = e2bus_gw

CFLAGS += -g -O3
LDFLAGS += -pthread -lzmq
LDFLAGS2 = $(LDFLAGS)

all: $(EXECS)

e2bus_gw: $(OBJS1)
	$(CC) -o e2bus_gw $(CFLAGS) $(OBJS1) $(LDFLAGS) 

$(OBJS1) : %.o : %.c 
	$(CC) -c $(CFLAGS) $< -o $@

clean:
	rm -f e2bus_gw *.o


