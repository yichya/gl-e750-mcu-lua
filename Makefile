include $(TOPDIR)/rules.mk

PKG_NAME:=gl-e750-mcu-lua
PKG_VERSION:=0.1.0
PKG_RELEASE:=1

PKG_LICENSE:=MPLv2
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=yichya <mail@yichya.dev>

PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=Custom
	CATEGORY:=Extra packages
	TITLE:=Mudi MCU Communication Stub
	DEPENDS:=+lua +luci-lib-nixio +luci-lib-jsonc +libubus-lua
endef

define Package/$(PKG_NAME)/description
	GL-iNet Mudi MCU Communication tool
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./gl-e750-mcu.lua $(1)/usr/bin/gl-e750-mcu.lua
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./e750_mcu $(1)/etc/init.d/e750_mcu
	$(INSTALL_BIN) ./mcu_shutdown $(1)/etc/init.d/mcu_shutdown
endef

$(eval $(call BuildPackage,$(PKG_NAME)))

