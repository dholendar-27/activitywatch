# =====================================
# Makefile for the ActivityWatch bundle
# =====================================
#
# [GUIDE] How to install from source:
#  - https://activitywatch.readthedocs.io/en/latest/installing-from-source.html
#
# We recommend creating and activating a Python virtualenv before building.
# Instructions on how to do this can be found in the guide linked above.
.PHONY: build install test clean clean_all

SHELL := /usr/bin/env bash

SUBMODULES := sd-core sd-client sd-qt sd-server sd-watcher-afk sd-watcher-window

# Include extras if SD_EXTRAS is true
ifeq ($(SD_EXTRAS),true)
	SUBMODULES := $(SUBMODULES) sd-notify sd-watcher-input
endif

# A function that checks if a target exists in a Makefile
# Usage: $(call has_target,<dir>,<target>)
define has_target
$(shell make -q -C $1 $2 >/dev/null 2>&1; if [ $$? -eq 0 -o $$? -eq 1 ]; then echo $1; fi)
endef

# Submodules with test/package/lint/typecheck targets
TESTABLES := $(foreach dir,$(SUBMODULES),$(call has_target,$(dir),test))
PACKAGEABLES := $(foreach dir,$(SUBMODULES),$(call has_target,$(dir),package))
LINTABLES := $(foreach dir,$(SUBMODULES),$(call has_target,$(dir),lint))
TYPECHECKABLES := $(foreach dir,$(SUBMODULES),$(call has_target,$(dir),typecheck))

# The `build` target
# ------------------
#
# What it does:
#  - Installs all the Python modules
#  - Builds the web UI and bundles it with sd-server
build:
	if [ -e "sd-core/.git" ]; then \
		echo "Submodules seem to already be initialized, continuing..."; \
	else \
		git submodule update --init --recursive; \
	fi
#	needed due to https://github.com/pypa/setuptools/issues/1963
#	would ordinarily be specified in pyproject.toml, but is not respected due to https://github.com/pypa/setuptools/issues/1963
	pip install 'setuptools>49.1.1'
	for module in $(SUBMODULES); do \
		echo "Building $$module"; \
		make --directory=$$module build SKIP_WEBUI=$(SKIP_WEBUI); \
	done
#   The below is needed due to: https://github.com/ActivityWatch/activitywatch/issues/173
	make --directory=sd-client build
	make --directory=sd-core build
#	Needed to ensure that the server has the correct version set
	python -c "import sd_server; print(sd_server.__version__)"


# Install
# -------
#
# Installs things like desktop/menu shortcuts.
# Might in the future configure autostart on the system.
install:
	make --directory=sd-qt install
# Installation is already happening in the `make build` step currently.
# We might want to change this.
# We should also add some option to install as user (pip3 install --user)

# Update
# ------
#
# Pulls the latest version, updates all the submodules, then runs `make build`.
update:
	git pull
	git submodule update --init --recursive
	make build


lint:
	@for module in $(LINTABLES); do \
		echo "Linting $$module"; \
		make --directory=$$module lint || { echo "Error in $$module lint"; exit 2; }; \
	done

typecheck:
	@for module in $(TYPECHECKABLES); do \
		echo "Typechecking $$module"; \
		make --directory=$$module typecheck || { echo "Error in $$module typecheck"; exit 2; }; \
	done

# Uninstall
# ---------
#
# Uninstalls all the Python modules.
uninstall:
	modules=$$(pip3 list --format=legacy | grep 'sd-' | grep -o '^sd-[^ ]*'); \
	for module in $$modules; do \
		echo "Uninstalling $$module"; \
		pip3 uninstall -y $$module; \
	done

test:
	@for module in $(TESTABLES); do \
		echo "Running tests for $$module"; \
		poetry run make -C $$module test || { echo "Error in $$module tests"; exit 2; }; \
    done

test-integration:
	# TODO: Move "integration tests" to sd-client
	# FIXME: For whatever reason the script stalls on Appveyor
	#        Example: https://ci.appveyor.com/project/ErikBjare/activitywatch/build/1.0.167/job/k1ulexsc5ar5uv4v
	# sd-server-python
	@echo "== Integration testing sd-server =="
	@pytest ./scripts/tests/integration_tests.py ./sd-server/tests/ -v

ICON := "sd-qt/media/logo/logo.png"

sd-qt/media/logo/logo.png:
	mkdir -p build/MyIcon.iconset
	sips -z 16 16     $(ICON) --out build/MyIcon.iconset/icon_16x16.png
	sips -z 32 32     $(ICON) --out build/MyIcon.iconset/icon_16x16@2x.png
	sips -z 32 32     $(ICON) --out build/MyIcon.iconset/icon_32x32.png
	sips -z 64 64     $(ICON) --out build/MyIcon.iconset/icon_32x32@2x.png
	sips -z 128 128   $(ICON) --out build/MyIcon.iconset/icon_128x128.png
	sips -z 256 256   $(ICON) --out build/MyIcon.iconset/icon_128x128@2x.png
	sips -z 256 256   $(ICON) --out build/MyIcon.iconset/icon_256x256.png
	sips -z 512 512   $(ICON) --out build/MyIcon.iconset/icon_256x256@2x.png
	sips -z 512 512   $(ICON) --out build/MyIcon.iconset/icon_512x512.png
	cp				  $(ICON)       build/MyIcon.iconset/icon_512x512@2x.png
	iconutil -c icns build/MyIcon.iconset
	rm -R build/MyIcon.iconset
	mv build/MyIcon.icns sd-qt/media/logo/logo.icns

dist/Sundial.app: sd-qt/media/logo/logo.png
	pyinstaller --clean --noconfirm sd.spec

dist/Sundial.dmg: dist/Sundial.app
	# NOTE: This does not codesign the dmg, that is done in the CI config
	pip install dmgbuild
	dmgbuild -s scripts/package/dmgbuild-settings.py -D app=dist/Sundial.app "Sundial" dist/Sundial.dmg

dist/notarize:
	./scripts/notarize.sh

package:
	rm -rf dist
	mkdir -p dist/Sundial
	for dir in $(PACKAGEABLES); do \
		make --directory=$$dir package; \
		cp -r $$dir/dist/$$dir dist/Sundial; \
	done
# Move sd-qt to the root of the dist folder
	mv dist/Sundial/sd-qt sd-qt-tmp
	mv sd-qt-tmp/* dist/Sundial
	rmdir sd-qt-tmp
# Remove problem-causing binaries
	rm -f dist/Sundial/libdrm.so.2       # see: https://github.com/ActivityWatch/activitywatch/issues/161
	rm -f dist/Sundial/libharfbuzz.so.0  # see: https://github.com/ActivityWatch/activitywatch/issues/660#issuecomment-959889230
# These should be provided by the distro itself
# Had to be removed due to otherwise causing the error:
#   sd-qt: symbol lookup error: /opt/activitywatch/libQt5XcbQpa.so.5: undefined symbol: FT_Get_Font_Format
	rm -f dist/Sundial/libfontconfig.so.1
	rm -f dist/Sundial/libfreetype.so.6
# Remove unnecessary files
	rm -rf dist/Sundial/pytz
# Builds zips and setups
	bash scripts/package/package-all.sh

clean:
	rm -rf build dist

# Clean all subprojects
clean_all: clean
	for dir in $(SUBMODULES); do \
		make --directory=$$dir clean; \
	done

clean-auto:
	rm -rIv **/sd-android/mobile/build
	rm -rIfv **/node_modules
