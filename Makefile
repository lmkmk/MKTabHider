TARGET = iphone:clang:latest:14.0
ARCHS = arm64 arm64e

INSTALL_TARGET_PROCESSES = Telegram

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MKTabHider

MKTabHider_FILES = Tweak.x
MKTabHider_CFLAGS = -fobjc-arc
MKTabHider_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
