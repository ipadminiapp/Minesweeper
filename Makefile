# Minesweeper — theos application build
# Required: theos installed. Set THEOS to its root, e.g.:
#   export THEOS=$HOME/theos
# This Makefile auto-detects common locations if THEOS is unset.

# --- locate theos -----------------------------------------------------------
ifeq ($(THEOS),)
  _CANDIDATES := $(HOME)/theos /opt/theos /usr/local/theos /var/theos $(HOME)/theos/theos
  $(foreach c,$(_CANDIDATES),\
    $(if $(wildcard $(c)/makefiles/common.mk),\
      $(if $(THEOS),,$(eval THEOS := $(c)))))
endif
ifeq ($(THEOS),)
  $(error THEOS not found. Install theos (https://theos.dev) and run: export THEOS=/path/to/theos)
endif
$(info THEOS = $(THEOS))

ARCHS = arm64
TARGET = iphone:clang:latest:9.0
INSTALL_TARGET = iphone

THEOS_DEVICE_IP ?=
THEOS_DEVICE_PORT ?= 22

include $(THEOS)/makefiles/common.mk
THEOS_MAKE_PATH := $(THEOS)/makefiles

APPLICATION_NAME = Minesweeper

Minesweeper_FILES = $(shell find Sources -name '*.m')
Minesweeper_FRAMEWORKS = UIKit Foundation
Minesweeper_CFLAGS = -fobjc-arc -Wno-error=unguarded-availability-new -Wno-unguarded-availability-new

include $(THEOS_MAKE_PATH)/application.mk

after-install::
	@echo "Refreshing icon cache on device..."
	install.exec "uicache" 2>/dev/null || install.exec "sbreload" 2>/dev/null || install.exec "respring" 2>/dev/null || true
