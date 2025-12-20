---
name: axe
description: Control iOS Simulators via accessibility APIs. Use this skill when the user wants to automate iOS simulator interactions, tap buttons by accessibility label, type text, swipe, take screenshots, describe the UI accessibility tree, or test iOS apps programmatically.
---

# axe - iOS Simulator Accessibility Control

Control iOS Simulators using accessibility APIs for UI automation and testing.

## Prerequisites

- Xcode with iOS Simulator
- `axe` CLI in PATH

## Getting Simulator UDID

Always use explicit UDIDs when multiple simulators might be running:

```bash
# List available simulators
xcrun simctl list devices available

# List only booted simulators
xcrun simctl list devices booted

# Boot a simulator
xcrun simctl boot "iPhone 17 Pro"

# Shutdown
xcrun simctl shutdown booted
xcrun simctl shutdown <UDID>
```

## axe Commands

### Describe UI (Accessibility Tree)

Get the full accessibility tree to find elements:

```bash
axe describe-ui --udid <UDID>
```

### Tap Elements

```bash
# By accessibility label (preferred)
axe tap --udid <UDID> --label "Button Label"

# By accessibility identifier
axe tap --udid <UDID> --id "buttonIdentifier"

# By coordinates (fallback, e.g., for tab bars)
axe tap --udid <UDID> -x 352 -y 832
```

### Type Text

```bash
axe type --udid <UDID> --text "Hello world"
```

### Swipe

**IMPORTANT**: Uses `--start-x/--start-y/--end-x/--end-y`, NOT `--from-x/--to-x`:

```bash
# Swipe up (scroll down)
axe swipe --udid <UDID> --start-x 200 --start-y 600 --end-x 200 --end-y 300

# Swipe down (scroll up)
axe swipe --udid <UDID> --start-x 200 --start-y 300 --end-x 200 --end-y 600
```

### Hardware Buttons

```bash
axe button --udid <UDID> --name home
axe button --udid <UDID> --name lock
```

## Screenshots (via simctl)

```bash
xcrun simctl io booted screenshot /tmp/screenshot.png
xcrun simctl io <UDID> screenshot /tmp/screenshot.png
```

## Common Gotchas

### axe swipe parameters
Use `--start-x/--start-y/--end-x/--end-y`, NOT `--from-x/--to-x`. This is a common mistake.

### simctl has no input command
`xcrun simctl io` only supports `screenshot` and `recordVideo`. For touch/swipe input, use `axe`.

### Sheet/modal timing
When opening a sheet and immediately tapping a button inside, add `sleep 0.5` between actions. The sheet needs time to fully present before buttons are tappable.

### Multiple simulators
Always use explicit UDID, not "booted", when multiple simulators are running. Check with `xcrun simctl list devices booted`.

### iOS 26+ Toggle issues
axe taps don't reliably trigger SwiftUI Toggle actions on iOS 26+. Manual testing may be required for toggle interactions.

### Entitlements require signing
`CODE_SIGNING_ALLOWED=NO` prevents entitlements (like HealthKit) from being applied. Use ad-hoc signing for entitlement-dependent features.

### Empty accessibility tree
If `axe describe-ui` returns an empty tree (frame `{0,0,0,0}`, no children) even though the app is visibly running, the simulator has entered a bad state. Fix by rebooting:

```bash
xcrun simctl shutdown <UDID> && xcrun simctl boot <UDID>
```

This is not an app code issue.

### Tab bar items
Tab bar items often require coordinates instead of labels. Use `axe describe-ui` to find element frames, then tap by coordinates. Tab bars are typically around y~832 on standard iPhone sizes.

## Recommended Workflow

- Run `xcrun simctl list devices booted` to get the UDID
- Use `axe describe-ui --udid <UDID>` to explore the accessibility tree
- Prefer `--label` for tapping when possible (more resilient to layout changes)
- Fall back to coordinates for elements without accessible labels
- Add `sleep 0.5` between actions that trigger animations/transitions
- Take screenshots with `xcrun simctl io` to verify state
