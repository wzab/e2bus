include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=drv-e2bus
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define KernelPackage/$(PKG_NAME)
  SUBMENU:=Experimental
  TITLE:=E2Bus driver
  FILES:=$(PKG_BUILD_DIR)/e2bus.ko
  KCONFIG:=  
endef

define KernelPackage/$(PKG_NAME)/description
  Experimental timer TIM1 connected to sysbus.
  For SCZR lab.
endef

EXTRA_KCONFIG:= \
	CONFIG_DRV_E2BUS=m

EXTRA_CFLAGS:= \
        -std=gnu99 -Wno-declaration-after-statement \
	$(patsubst CONFIG_%, -DCONFIG_%=1, $(patsubst %=m,%,$(filter %=m,$(EXTRA_KCONFIG)))) \
	$(patsubst CONFIG_%, -DCONFIG_%=1, $(patsubst %=y,%,$(filter %=y,$(EXTRA_KCONFIG)))) \

MAKE_OPTS:= \
	$(KERNEL_MAKE_FLAGS) \
	ARCH="$(LINUX_KARCH)" \
	CROSS_COMPILE="$(TARGET_CROSS)" \
	SUBDIRS="$(PKG_BUILD_DIR)" \
	EXTRA_CFLAGS="$(EXTRA_CFLAGS)" \
	$(EXTRA_KCONFIG)

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" \
		$(MAKE_OPTS) \
		modules
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include
	$(CP) src/*.h $(1)/usr/include
endef

$(eval $(call KernelPackage,$(PKG_NAME)))

