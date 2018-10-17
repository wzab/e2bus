################################################################################
#
# E2BUS-module
#
################################################################################

E2BUS_MODULE_VERSION = 1.0
E2BUS_MODULE_SITE    = $(BR2_EXTERNAL_E2B_MINI_PATH)/src/e2bus
E2BUS_MODULE_SITE_METHOD = local
E2BUS_MODULE_LICENSE = LGPLv2.1/GPLv2 

$(eval $(kernel-module))
$(eval $(generic-package))
