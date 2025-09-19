export DEBUG = 0
export THEOS_STRICT_LOGOS = 0
export ERROR_ON_WARNINGS = 0
export LOGOS_DEFAULT_GENERATOR = internal

# Rootless 插件配置
export THEOS_PACKAGE_SCHEME = rootless
THEOS_PACKAGE_INSTALL_PREFIX = /var/jb

# 直接输出到根路径
export THEOS_PACKAGE_DIR = $(CURDIR)

# 设置工具路径
export PATH := $(CURDIR):$(PATH)

# TARGET
ARCHS = arm64
TARGET = iphone:clang:latest:15.0
# 引入 Theos 的通用设置
include $(THEOS)/makefiles/common.mk

# 插件名称
TWEAK_NAME = APP_hook

# 源代码文件
SWIFT_SOURCES = $(shell find . -name "*.swift" -not -name "Package.swift")
$(TWEAK_NAME)_FILES = load.s $(SWIFT_SOURCES)

# 编译标志
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -w
$(TWEAK_NAME)_CFLAGS += -Wno-everything
$(TWEAK_NAME)_CFLAGS += -Wno-incomplete-implementation
$(TWEAK_NAME)_CFLAGS += -Wno-protocol

# Swift编译
$(TWEAK_NAME)_SWIFTFLAGS = -I. -sdk $(THEOS)/sdks/iPhoneOS15.6.sdk/
$(TWEAK_NAME)_SWIFTFLAGS += -Xfrontend -disable-implicit-string-processing-module-import

include $(THEOS_MAKE_PATH)/tweak.mk
.PHONY: build-only
build-only:
	@echo "开始构建APP_hook.dylib（跳过签名和打包）..."
	@make --no-print-directory internal-tweak-compile
	@echo "构建完成！dylib文件位于：$(THEOS_OBJ_DIR)/debug/$(TWEAK_NAME).dylib"
.PHONY: build-spm
build-spm:
	@echo "使用Swift Package Manager构建..."
	swift build -c release -Xswiftc -target -Xswiftc arm64-apple-ios15.0