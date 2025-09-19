# 包元数据
PACKAGE_IDENTIFIER = com.pxx917144686.app-hook
PACKAGE_VERSION = 0.0.2
PACKAGE_ARCHITECTURE = iphoneos-arm64
PACKAGE_REVISION = 1
PACKAGE_SECTION = Tweaks
PACKAGE_DEPENDS = firmware (>= 15.0), mobilesubstrate
PACKAGE_DESCRIPTION = APP_Hook

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
TWEAK_NAME = APP_hook

# 源文件（支持分目录）
SWIFT_ROOT := $(filter-out Package.swift, $(wildcard *.swift))
SWIFT_SK1  := $(shell find Sk1 -name "*.swift" 2>/dev/null)
SWIFT_SK2  := $(shell find Sk2 -name "*.swift" 2>/dev/null)
SWIFT_CORE := $(shell find Core -name "*.swift" 2>/dev/null)
SWIFT_UI   := $(shell find UI -name "*.swift" 2>/dev/null)
SWIFT_MODELS := $(shell find Models -name "*.swift" 2>/dev/null)
JINX_FILES := $(shell find Jinx -name "*.swift" 2>/dev/null | grep -v Package.swift)
SOURCE_FILES := $(SWIFT_ROOT) $(SWIFT_SK1) $(SWIFT_SK2) $(SWIFT_CORE) $(SWIFT_UI) $(SWIFT_MODELS) $(JINX_FILES)
APP_hook_FILES = $(SOURCE_FILES) load.s
APP_hook_CFLAGS = -fobjc-arc -fmodules
APP_hook_SWIFTFLAGS = -I. -sdk $(SYSROOT)

# Theos 插件规则
include $(THEOS_MAKE_PATH)/tweak.mk