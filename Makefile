ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:16.0
INSTALL_TARGET_PROCESSES = SchubertApp

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = QishuiVIPAuto

QishuiVIPAuto_FILES = Tweak.xm
QishuiVIPAuto_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
