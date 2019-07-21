all : e2test e2bus_gw
CFLAGS += -O3
OBJS1 := e2test.o 
e2test: $(OBJS1)
	$(CC) -o e2test $(CFLAGS) $(LDFLAGS) -lzmq -pthread $(OBJS1) 
$(OBJS1) : %.o : %.c
	$(CC) -c $(CFLAGS) $< -o $@

OBJS2 := e2bus_gw.o 
e2bus_gw: $(OBJS2)
	$(CC) -o e2bus_gw $(CFLAGS) $(LDFLAGS) -pthread $(OBJS2) -lzmq
$(OBJS2) : %.o : %.c
	$(CC) -c $(CFLAGS) $< -o $@
