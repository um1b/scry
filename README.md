# Scry

A minimal macOS menu bar app that copies a screenshot to your clipboard with ⌘⇧4 — intercepting the default shortcut and using the native selection UI.

## Requirements

- macOS 13+
- Xcode 15+

## Installation

There is no pre-built binary. You need to build it yourself:

1. Clone the repo
2. Open `Scry.xcodeproj` in Xcode
3. Set your development team in the target's Signing settings
4. Build and run (⌘R)

On first launch, grant **Accessibility** (for the global hotkey) and **Screen Recording** (for the capture) when prompted.

## Usage

Press **⌘⇧4** → select a region → screenshot is in your clipboard.
