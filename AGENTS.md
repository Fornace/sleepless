# Sleepless

Sleepless is a native macOS menu bar app that controls the system-wide sleep setting.

The source lives in `Sleepless/`, with app assets in `Sleepless/Assets.xcassets`. `project.yml` is the XcodeGen project definition. Generate the Xcode project with XcodeGen and build the Sleepless scheme with Xcode.

The menu must report the actual `SleepDisabled` setting. Changing it requires macOS administrator authentication. Do not change the system sleep setting just to build the app.
