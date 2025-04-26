# VolumeIconToggle

A simple macOS menu bar application that allows you to quickly toggle the visibility of the system volume icon in the menu bar.

## Features

- Toggle the volume icon with a single click
- Menu bar icon indicates current state (filled when volume icon is visible)
- Keyboard shortcut (⌘T) for quick toggling
- Minimal and unobtrusive interface

## Requirements

- macOS 11.0 (Big Sur) or later

## Installation

### Using Homebrew

```bash
brew tap georgemastro/VolumeIconToggle
brew install volume-icon-toggle
brew services start volume-icon-toggle
```

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/georgemastro/VolumeIconToggle.git
cd VolumeIconToggle
```

2. Build and install:
```bash
swift build -c release
sudo cp .build/release/VolumeIconToggle /usr/local/bin/
```

3. Run the application:
```bash
VolumeIconToggle
```

## Usage

### Menu Bar Controls

- Click the menu bar icon to access:
  - Toggle Volume Icon (⌘T)
  - Quit (⌘Q)

### Icon States

- Filled speaker icon: Volume icon is currently visible
- Regular speaker icon: Volume icon is currently hidden

## Troubleshooting

If the toggle doesn't work:

1. Make sure you have the necessary permissions:
   - System Settings > Privacy & Security > Accessibility
   - Add VolumeIconToggle to the list of allowed applications

2. Try restarting the SystemUIServer manually:
```bash
killall SystemUIServer
```

## License

This project is open source and available under the MIT License.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. 