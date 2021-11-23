# Build module only if kernel supports DRV_E2BUS
ifdef CONFIG_DRV_E2BUS
obj-m += e2bus.o
endif

KDIR ?= /lib/modules/$(shell uname -r)/build

modules:
	$(MAKE) -C $(KDIR) M=$$PWD modules

modules_install:
	$(MAKE) -C $(KDIR) M=$$PWD modules_install

clean:
	$(MAKE) -C $(KDIR) M=$$PWD clean
