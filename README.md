# HyperLayer

Caps Lock as a programmable keyboard layer for macOS.

![HyperLayer screenshot](docs/assets/hyperlayer.png)

HyperLayer suppresses the normal Caps Lock behavior and lets you map `Caps Lock + key` to any keyboard shortcut, including modifier combinations such as `Ctrl+Tab`, `Cmd+Shift+P`, or `Opt+Left Arrow`.

## Why

I created HyperLayer because I was unsatisfied with the complexity of setting up Karabiner and Kanata, and I did not want to use a commercial product that felt like overkill for my needs.

## Features

- Caps Lock layer key.
- Per-key output shortcuts.
- Recorder buttons for trigger keys and output shortcuts.
- Automatic permission checks.
- Saved configuration.
- Restores the original Caps Lock mapping when disabled or quit.

## Build

```sh
xcodegen generate
xcodebuild -project HyperLayer.xcodeproj -scheme HyperLayer -configuration Debug -derivedDataPath build build
```

## Downloads

- Latest build: download the `HyperLayer-main` artifact from the latest successful `Build HyperLayer` run on `main`.
- Releases: each `v*` release includes a zipped app and a SHA-256 checksum.

## Run

```sh
open build/Build/Products/Debug/HyperLayer.app
```

## Permissions

HyperLayer needs Accessibility and Input Monitoring.

The app requests Accessibility and opens the relevant System Settings panes when macOS requires manual approval. Input Monitoring is granted manually in System Settings. HyperLayer rechecks permissions automatically every 10 seconds.

## Fn / Globe Limitation

Mappings that use the `Fn` / Globe key as part of the output are unreliable.

HyperLayer can record and display `Fn`, but macOS does not treat synthesized keyboard events with the `Fn` flag the same way it treats real hardware `Fn` input. In particular, `Fn+Arrow` can be translated to `Home` / `End`, and native macOS shortcuts such as `Ctrl+Fn+Left Arrow` or `Ctrl+Fn+Right Arrow` may not fire when emitted by HyperLayer.

This appears to be a macOS event-synthesis limitation rather than a configuration issue.

## How It Works

When enabled, HyperLayer maps physical Caps Lock to F18 with `hidutil`, consumes that layer key through a keyboard event tap, and emits the configured output shortcut for matching combinations.
