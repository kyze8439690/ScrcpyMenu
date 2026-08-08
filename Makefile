APP_NAME := ScrcpyMenu
BUILD_DIR := .build/release
APP_DIR := $(APP_NAME).app

.PHONY: build app run clean

build:
	swift build -c release

app: build
	rm -rf "$(APP_DIR)"
	mkdir -p "$(APP_DIR)/Contents/MacOS"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP_DIR)/Contents/MacOS/$(APP_NAME)"
	cp Resources/Info.plist "$(APP_DIR)/Contents/Info.plist"
	codesign -s - --force "$(APP_DIR)"

run: app
	open "$(APP_DIR)"

clean:
	swift package clean
	rm -rf "$(APP_DIR)"
