# Sleepless

A small, native macOS menu bar app for keeping your Mac awake. Select the eye icon to turn Sleepless on or off and see the current system setting.

## How it works

Sleepless reads the system's `SleepDisabled` setting with `pmset -g`. Turning it on runs `pmset -a disablesleep 1`, which disables system sleep, including sleep when the lid closes. Turning it off runs `pmset -a disablesleep 0`, returning control to macOS and your power settings. macOS asks an administrator to authenticate when the setting changes.

The setting applies to the whole Mac and remains in effect after Sleepless quits. Other apps can also prevent sleep. Keep your Mac ventilated when the lid is closed and monitor the battery.

## Requirements

- macOS 14 or later
- An administrator account to change the sleep setting
- Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) to build from source

## Build and run

Clone the repository, then run:

```sh
xcodegen generate
xcodebuild -project Sleepless.xcodeproj -scheme Sleepless -configuration Debug \
  -derivedDataPath build build
open build/Build/Products/Debug/Sleepless.app
```

The eye appears in the menu bar. If it is hidden, expand the menu bar's hidden items. The icon reflects the system setting and refreshes when you open the menu.

## License

Sleepless is available under the [MIT License](LICENSE).

## Links

- `man pmset` in Terminal for the macOS power management manual
- [Fornace](https://fornace.net)
