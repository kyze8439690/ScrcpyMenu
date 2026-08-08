APP_NAME := ScrcpyMenu
APP_DIR := $(APP_NAME).app
ICONSET_DIR := build/$(APP_NAME).iconset
UNIVERSAL_BIN := build/$(APP_NAME)

.PHONY: build icon app run clean

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
	cp Resources/AppIcon.icns "$(APP_DIR)/Contents/Resources/AppIcon.icns"
	codesign -s - --force "$(APP_DIR)"

run: app
	open "$(APP_DIR)"

clean:
	swift package clean
	rm -rf "$(APP_DIR)" build
