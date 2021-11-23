include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=drv-e2bus
PKG_VERSION:=0.1
PKG_RELEASE:=1

#PKG_BUILD_DIR:=$(KERNEL_BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define KernelPackage/drv-e2bus
  SUBMENU:=Experimental
  TITLE:=E2Bus driver
  FILES:=$(PKG_BUILD_DIR)/e2bus.ko
endef

define KernelPackage/drv-e2bus/description
  Experimental timer TIM1 connected to sysbus.
  For SCZR lab.
endef

MAKE_OPTS:= \
	ARCH="$(LINUX_KARCH)" \
	CROSS_COMPILE="$(TARGET_CROSS)" \
	EXTRA_CFLAGS="-std=gnu99 -Wno-declaration-after-statement" \
	M="$(PKG_BUILD_DIR)"

define Build/Prepare
	cp src/* $(PKG_BUILD_DIR)
endef

define Build/Compile
	+$(MAKE) -C "$(LINUX_DIR)" \
		$(MAKE_OPTS) \
		CONFIG_DRV_E2BUS=m \
		modules
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include
	$(CP) src/*.h $(1)/usr/include
endef

$(eval $(call KernelPackage,drv-e2bus))

