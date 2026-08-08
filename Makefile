APP_NAME := ScrcpyMenu
ICONSET_DIR := build/$(APP_NAME).iconset
UNIVERSAL_BIN := build/$(APP_NAME)
VERSION ?= dev
DEV ?= 1

ifeq ($(DEV),1)
APP_DIR := $(APP_NAME) Dev.app
else
APP_DIR := $(APP_NAME).app
endif

.PHONY: build icon app zip run clean

build:
	mkdir -p build
	swift build -c release --triple arm64-apple-macosx
	swift build -c release --triple x86_64-apple-macosx
	lipo -create \
		.build/arm64-apple-macosx/release/$(APP_NAME) \
		.build/x86_64-apple-macosx/release/$(APP_NAME) \
		-output "$(UNIVERSAL_BIN)"

icon:
	mkdir -p "$(ICONSET_DIR)"
	swift scripts/generate-icon.swift "$(ICONSET_DIR)"
	iconutil -c icns "$(ICONSET_DIR)" -o Resources/AppIcon.icns

app: build
	rm -rf "$(APP_DIR)"
	mkdir -p "$(APP_DIR)/Contents/MacOS"
	mkdir -p "$(APP_DIR)/Contents/Resources"
	cp "$(UNIVERSAL_BIN)" "$(APP_DIR)/Contents/MacOS/$(APP_NAME)"
	cp Resources/Info.plist "$(APP_DIR)/Contents/Info.plist"
ifeq ($(DEV),1)
	swift scripts/generate-icon.swift "build/$(APP_NAME)-Dev.iconset" dev > /dev/null
	iconutil -c icns "build/$(APP_NAME)-Dev.iconset" -o build/AppIcon-Dev.icns
	cp build/AppIcon-Dev.icns "$(APP_DIR)/Contents/Resources/AppIcon.icns"
	/usr/libexec/PlistBuddy -c "Set :CFBundleName $(APP_NAME) Dev" "$(APP_DIR)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.yugy.scrcpy-menu.dev" "$(APP_DIR)/Contents/Info.plist"
else
	cp Resources/AppIcon.icns "$(APP_DIR)/Contents/Resources/AppIcon.icns"
endif
	codesign -s - --force "$(APP_DIR)"

run: app
	open "$(APP_DIR)"

zip:
	$(MAKE) DEV=0 app
	ditto -c -k --keepParent "$(APP_NAME).app" "build/$(APP_NAME)-$(VERSION).zip"

clean:
	swift package clean
	rm -rf "$(APP_NAME).app" "$(APP_NAME) Dev.app" build
