# SkyrimNet Status Widget

A customizable SkyUI HUD widget that displays real-time status information for [SkyrimNet](https://github.com/yourusername/SkyrimNet), including whisper mode and recording indicators.

## Features

<p align="center">
  <img src="images/widgetshowcase.jpg">
</p>
<h6 align="center">Left: Whisper mode disabled | Center: Whisper mode enabled | Right: Recording indicator</h6>

### Current Status Indicators
- **Whisper Mode**: Shows whether whisper mode is active (hollow mic = off, filled mic = on)
- **Recording Indicator**: Displays when voice recording is active (open mic or push-to-talk)

### Customization Options
- **Positioning**: Choose from presets (Bottom Right, Bottom Left, Top Right, Top Left) or custom positioning
- **Anchoring**: Anchor widget to screen edges for resolution independence
- **Size**: Adjustable from 50% to 200%
- **Opacity**: Control transparency from 0% (invisible) to 100% (fully opaque)
- **Auto-hide**: Optionally hide widget when inactive (no whisper mode and not recording)

### Update Modes
- **Polling Mode** (Default): Periodically checks status with configurable interval (0.1-1.0 seconds)
- **Hotkey Mode**: Updates triggered by hotkey presses (experimental, may have edge cases)

## Requirements

- [SKSE64](https://skse.silverlock.org/)
- [SkyUI](https://www.nexusmods.com/skyrimspecialedition/mods/12604)
- [SkyrimNet](https://github.com/yourusername/SkyrimNet)

## Installation

1. Install all requirements
2. Install this mod with your mod manager or manually extract to your Data folder
3. Load order: Place after SkyUI
4. Launch game and configure via MCM

## Configuration (MCM)

Access the mod configuration menu (MCM) to customize the widget:

### Widget Display
- **Show Widget**: Master toggle to show/hide the widget
- **Size**: Scale the widget (50-200%)
- **Opacity**: Adjust transparency (0-100%)
- **Show Recording Indicator**: Toggle recording state display
- **Hide When Inactive**: Auto-hide when not in whisper mode and not recording
- **Use Hotkey Mode**: Switch to hotkey-based updates (instant but experimental)
- **Poll Interval**: How often to check status in polling mode (0.1-1.0 seconds)

### Position & Layout
- **Position Preset**: Quick position presets (Bottom Right, Bottom Left, Top Right, Top Left, User Defined)
- **X Position / Y Position**: Manual positioning (0-1280 / 0-720 for 720p)
- **Horizontal/Vertical Anchor**: Anchor widget to screen edges (Left/Middle/Right, Top/Middle/Bottom)

### Info
- **Whisper Mode**: Displays current whisper mode status (read-only)

## Known Limitations

- Hotkey mode requires reload to update keybind changes
- Hotkey mode has edge cases with push-to-talk held during reload
- Recording state may briefly show incorrect value after save reload (updates within ~1.5 seconds)

## Credits

Special thanks to:
- SkyrimNet development team
- SkyUI team for the widget framework
