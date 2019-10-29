include $(TOPDIR)/rules.mk

PKG_NAME:=e2bus-gw
PKG_RELEASE:=1

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)
include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=WZab
  CATEGORY:=Examples
  DEPENDS:=+kmod-drv-e2bus +libzmq-nc
  TITLE:=E2Bus gateway
endef

define Package/$(PKG_NAME)/description
  Tu mogę stworzyć jakiś opis
endef

define Build/Configure
endef

define Build/Compile
        $(MAKE) -C $(PKG_BUILD_DIR) \
                CC="$(TARGET_CC)" \
                CFLAGS="$(TARGET_CFLAGS) -Wall" \
                LDFLAGS="$(TARGET_LDFLAGS) -lzmq"
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/e2bus_gw $(1)/usr/bin
endef

$(eval $(call BuildPackage,$(PKG_NAME)))

