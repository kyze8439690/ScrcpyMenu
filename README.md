# ScrcpyMenu

A lightweight macOS menu bar GUI for [scrcpy](https://github.com/Genymobile/scrcpy). Click the menu bar icon and select an Android device to start/stop a scrcpy mirroring window in one click.

[中文文档](README.zh-CN.md)

![screenshot](screenshot.png)

## Features

- Persistent menu bar icon (SF Symbol, adapts to light/dark mode)
- Lists all devices detected by `adb devices` (including wireless adb devices) with human-readable device names
- Click a device to start scrcpy, click again to stop; running devices show a ● status indicator
- Auto-refreshes the device list when the menu opens; manual Refresh also available
- `unauthorized` / `offline` devices are grayed out with their status shown
- Shows an alert with the error message when startup fails; each scrcpy process output is written to `~/Library/Logs/ScrcpyMenu/`
- Automatically cleans up all scrcpy processes started by this app when quitting
- Checks for scrcpy / adb dependencies on launch and shows installation instructions if missing

## Dependencies

```bash
brew install scrcpy android-platform-tools
```

## Build & Run

```bash
make app   # release build and package ScrcpyMenu.app (ad-hoc signed)
make run   # build and launch
```

Or use SwiftPM directly:

```bash
swift build -c release
```

## Install (Direct Download)

Download the latest release zip from [Releases](../../releases/latest) and extract it. Since the app is only ad-hoc signed (not notarized), you need to bypass Gatekeeper on first launch using one of these methods:

1. Right-click `ScrcpyMenu.app` → Open → click "Open" in the dialog;
2. If prompted "damaged/unverified developer", run in Terminal:
   ```bash
   xattr -cr /path/to/ScrcpyMenu.app
   ```
   Then double-click to open normally;
3. Or go to System Settings → Privacy & Security → click "Open Anyway" at the bottom.

## Technical Notes

- Pure Swift Package (executable target), no Xcode project
- AppKit `NSStatusItem` + `NSMenu`, no third-party dependencies
- macOS 13+, Bundle ID: `com.yugy.scrcpy-menu`

## Disclaimer

- This project is only a third-party GUI wrapper for [scrcpy](https://github.com/Genymobile/scrcpy) and has no affiliation with or official relationship to Genymobile.
- scrcpy is copyright Genymobile and is released under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).
