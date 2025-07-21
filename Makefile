# 包元数据
PACKAGE_IDENTIFIER = com.pxx917144686.satellajailed
PACKAGE_VERSION = 0.0.1
PACKAGE_ARCHITECTURE = iphoneos-arm64
PACKAGE_REVISION = 1
PACKAGE_SECTION = Tweaks
PACKAGE_DEPENDS = firmware (>= 15.0), mobilesubstrate
PACKAGE_DESCRIPTION = SatellaJailed++

# 直接输出到根路径
export THEOS_PACKAGE_DIR = $(CURDIR)

# Rootless 插件配置
export THEOS_PACKAGE_SCHEME = rootless
THEOS_PACKAGE_INSTALL_PREFIX = /var/jb

# TARGET
ARCHS = arm64
TARGET = iphone:clang:latest:15.0

# Theos 的通用设置
include $(THEOS)/makefiles/common.mk

# 插件名
TWEAK_NAME = SatellaJailed

# 源文件
SWIFT_FILES := $(filter-out Package.swift, $(wildcard *.swift))
JINX_FILES := $(shell find Jinx -name "*.swift" 2>/dev/null || echo "")
SOURCE_FILES := $(SWIFT_FILES) $(JINX_FILES)
SatellaJailed_FILES = $(SOURCE_FILES) load.s
SatellaJailed_CFLAGS = -fobjc-arc -fmodules
SatellaJailed_SWIFTFLAGS = -I. -sdk $(SYSROOT)

# Theos 插件规则
include $(THEOS_MAKE_PATH)/tweak.mk
