################################################################################
#
# e2test
#
################################################################################

E2TEST_VERSION = 1.0
E2TEST_SITE = $(BR2_EXTERNAL_E2B_MINI_PATH)/src/e2test
E2TEST_SITE_METHOD = local
E2TEST_DEPENDENCIES = zeromq

define E2TEST_BUILD_CMDS
   $(MAKE) $(TARGET_CONFIGURE_OPTS) all -C $(@D)
endef
define E2TEST_INSTALL_TARGET_CMDS 
   $(INSTALL) -D -m 0755 $(@D)/e2test $(TARGET_DIR)/usr/bin 
   $(INSTALL) -D -m 0755 $(@D)/e2bus_gw $(TARGET_DIR)/usr/bin 
endef
E2TEST_LICENSE = Proprietary

$(eval $(generic-package))
