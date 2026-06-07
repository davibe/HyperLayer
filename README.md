# HyperLayer

HyperLayer is a macOS GUI app that turns Caps Lock into a configurable keyboard layer.

While enabled, HyperLayer maps the physical Caps Lock key to F18 with `hidutil`, consumes F18 through a keyboard event tap, and emits the configured output shortcut when you press Caps Lock plus a mapped key.

## Build

```sh
xcodegen generate
xcodebuild -project HyperLayer.xcodeproj -scheme HyperLayer -configuration Debug -derivedDataPath build build
```

The built app is under:

```text
build/Build/Products/Debug/HyperLayer.app
```

## Permissions

HyperLayer needs:

- Accessibility, to suppress intercepted events and post replacement shortcuts.
- Input Monitoring, to receive global keyboard events.

The app requests Accessibility automatically. macOS may require opening System Settings for Input Monitoring; HyperLayer includes buttons for both panes and polls until the permissions are granted.
