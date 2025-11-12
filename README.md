# SailfishOS Meetings - Sailfish OS Meeting Logs Viewer

A native Sailfish OS application for browsing and reading Sailfish OS community meeting logs from [irclogs.sailfishos.org](https://irclogs.sailfishos.org/meetings/sailfishos-meeting/).

## Features

- Browse meetings by year (2024 onwards)
- View meeting summaries with topics, participants, and action items
- Read full IRC conversation logs with colorized syntax
- Native Silica UI with pull-down menus and smooth navigation
- Asynchronous loading with busy indicators
- Support for all Sailfish OS device orientations

## Building

### Requirements

- Sailfish SDK (Platform SDK with mb2 tools)
- Qt 5.6+
- Qt Network module

### Local Build

```bash
qmake sailfishos-meetings.pro
make
```

### Build RPM Package

```bash
# For specific architecture
mb2 -t SailfishOS-latest-armv7hl build
mb2 -t SailfishOS-latest-aarch64 build
mb2 -t SailfishOS-latest-i486 build
```

## Installation

Download the appropriate RPM for your device from the [Releases](../../releases) page:

- **armv7hl**: Jolla 1, Xperia X, XA2
- **aarch64**: Xperia 10 II, III, IV, 10 V
- **i486**: Emulator

Install via:
```bash
devel-su
rpm -i sailfishos-meetings-*.rpm
```

## CI/CD

The project uses GitHub Actions to automatically build RPM packages for all architectures when a version tag is pushed:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Packages are automatically attached to GitHub releases.

## Architecture

- **C++ Backend**: `MeetingManager` class handles HTTP requests and HTML parsing
- **QML Frontend**: 4-level navigation (Year → Meetings → Summary → Full Log)
- **Data Source**: https://irclogs.sailfishos.org/meetings/sailfishos-meeting/

## License

BSD-3-Clause (see LICENSE file)

## Credits

Original template based on Jolla's Sailfish OS application template.
