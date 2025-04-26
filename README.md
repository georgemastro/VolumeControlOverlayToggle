# VolumeControlOverlayToggle

Buy Me a Coffee: buymeacoffee.com/georgemastro

A simple macOS menu bar application that allows you to quickly toggle the visibility of the system volume control overlay in the menu bar.

## Features

- Toggle the volume overlay with a single click
- Menu bar icon indicates current state (filled when overlay is visible)
- Global keyboard shortcut (⌘⌥⇧O) for quick toggling
- Minimal and unobtrusive interface

## Requirements

- macOS 11.0 (Big Sur) or later

## Installation

### Using Homebrew

```bash
brew tap georgemastro/VolumeControlOverlayToggle
brew install volume-control-overlay-toggle
```

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/georgemastro/VolumeControlOverlayToggle.git
cd VolumeControlOverlayToggle
```

2. Build and install:
```bash
swift build -c release
sudo cp .build/release/VolumeControlOverlayToggle /usr/local/bin/
```

3. Run the application:
```bash
VolumeControlOverlayToggle
```

## Usage

### Menu Bar Controls

- Left-click the menu bar icon to toggle the overlay
- Right-click the menu bar icon to access:
  - Toggle Volume Control Overlay (⌘⌥⇧O)
  - Start at Login
  - Quit (⌘Q)

### Icon States

- Filled speaker icon: Overlay is currently visible
- Regular speaker icon: Overlay is currently hidden

## Troubleshooting

If the toggle doesn't work:

1. Make sure you have the necessary permissions:
   - System Settings > Privacy & Security > Accessibility
   - Add VolumeControlOverlayToggle to the list of allowed applications

2. Try restarting the SystemUIServer manually:
```bash
killall SystemUIServer
```

## License

This project is open source and available under the MIT License.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. 