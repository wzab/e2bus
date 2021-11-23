all : e2test 
CFLAGS += -g -O3
OBJS1 := e2test.o 
e2test: $(OBJS1)
	$(CC) -o e2test $(CFLAGS) $(LDFLAGS) -lzmq -pthread $(OBJS1) 
$(OBJS1) : %.o : %.c
	$(CC) -c $(CFLAGS) $< -o $@

