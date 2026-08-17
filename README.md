# SailfishOS Meetings - Sailfish OS Meeting Logs Viewer

A native Sailfish OS application for browsing and reading Sailfish OS community meeting logs from [irclogs.sailfishos.org](https://irclogs.sailfishos.org/meetings/sailfishos-meeting/), including the older [Mer project meetings](https://irclogs.sailfishos.org/meetings/mer-meeting/) (2011-2020).

## Features

- Browse meetings by year (auto-detected from the server), Mer and Sailfish OS series merged
- View meeting summaries with topics, participants, and action items
- Read full IRC conversation logs with colorized nicks and avatars
- Selectable display styles for meeting notes (`#info`, `#topic`...) and for the conversation
- Wrapped `#info <nick>` quotes are joined back into readable paragraphs, Jolla answers highlighted
- Global search and aggregated `#action`/`#agreed` items across a year
- Filter log messages by participant, highlight your own nick
- Favorites, read/unread tracking, meeting statistics
- Next meeting date with calendar export (30 min reminder) and agenda link
- Offline reading of previously loaded meetings (disk cache)
- Native Silica UI, French and German translations
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
