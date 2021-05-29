include $(TOPDIR)/rules.mk

PKG_NAME:=gl-e750-mcu-lua
PKG_VERSION:=0.2.0
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
	DEPENDS:=+lua +luci-lib-nixio +luci-lib-jsonc +libubus-lua +socat
endef

define Package/$(PKG_NAME)/description
	GL-iNet Mudi MCU Communication tool
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./root/usr/bin/atrepl $(1)/usr/bin/atrepl
	$(INSTALL_BIN) ./root/usr/bin/gl_e750_mcu.lua $(1)/usr/bin/gl_e750_mcu.lua
	$(INSTALL_BIN) ./root/usr/bin/gl_e750_monitor.lua $(1)/usr/bin/gl_e750_monitor.lua
	$(INSTALL_DIR) $(1)/etc/hotplug.d/button
	$(INSTALL_BIN) ./root/etc/hotplug.d/button/gl_e750_monitor $(1)/etc/hotplug.d/button/gl_e750_monitor
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/gl_e750_mcu $(1)/etc/init.d/gl_e750_mcu
	$(INSTALL_BIN) ./root/etc/init.d/mcu_shutdown $(1)/etc/init.d/mcu_shutdown
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
