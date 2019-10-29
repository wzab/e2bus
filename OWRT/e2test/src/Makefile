OBJS1 =e2test.o 

EXECS = e2test

CFLAGS += -g -O3
LDFLAGS += -pthread 
LDFLAGS2 = $(LDFLAGS)

all: $(EXECS)

e2bus_gw: $(OBJS1)
	$(CC) -o e2test $(CFLAGS) $(OBJS1) $(LDFLAGS) 

$(OBJS1) : %.o : %.c 
	$(CC) -c $(CFLAGS) $< -o $@

clean:
	rm -f e2test *.o


