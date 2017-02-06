ARCHS = armv7 arm64
include $(THEOS)/makefiles/common.mk

TOOL_NAME = StashApps
StashApps_FILES = main.mm stashutils.mm appstasher.mm binlibstasher.mm fstabutil.mm

include $(THEOS_MAKE_PATH)/tool.mk
SUBPROJECTS += csstashedappexecutable
include $(THEOS_MAKE_PATH)/aggregate.mk
