# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Sailfish OS application for browsing and reading Sailfish OS community meeting logs from https://irclogs.sailfishos.org/meetings/sailfishos-meeting/. The app provides a native Silica UI to navigate meetings by year, view summaries, and read full IRC conversation logs.

## Architecture

**Technology Stack**:
- Sailfish OS with Qt 5.6 and Silica components
- C++ backend with QML frontend
- QNetworkAccessManager for async HTTP requests
- Build system: qmake + mb2 (Sailfish SDK)

**C++ Backend** (src/):
- `meetingmanager.h/cpp`: Manages fetching and parsing of meeting data from irclogs.sailfishos.org
- `meeting.h/cpp`: Data model for individual meetings with Q_PROPERTY exports to QML
- `sailfishos-meetings.cpp`: Entry point that registers QML types and creates singleton MeetingManager

**QML Frontend** (qml/pages/):
- `YearSelectionPage.qml`: Initial page listing available years (2024+)
- `MeetingListPage.qml`: Lists all meetings for selected year
- `MeetingSummaryPage.qml`: Displays meeting summary (.html) with formatted content
- `MeetingLogPage.qml`: Displays full IRC log (.log.html) with timestamp and username colorization

## Building

```bash
# Local build with Sailfish SDK
qmake sailfishos-meetings.pro
make

# Build RPM package for specific architecture
mb2 -t SailfishOS-latest-armv7hl build
mb2 -t SailfishOS-latest-aarch64 build
mb2 -t SailfishOS-latest-i486 build
```

## CI/CD

GitHub Actions workflow (`.github/workflows/build.yml`) automatically builds RPM packages for all architectures (armv7hl, aarch64, i486) when a version tag is pushed:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Packages are automatically attached to GitHub releases.

## Data Sources

- **Base URL**: https://irclogs.sailfishos.org/meetings/sailfishos-meeting/
- **File patterns**:
  - Summary: `sailfishos-meeting.YYYY-MM-DD-HH.MM.html`
  - Full log: `sailfishos-meeting.YYYY-MM-DD-HH.MM.log.html`
- Meetings are parsed via regex and sorted by date (newest first)

## Important Notes

- Uses Qt 5.6 features only (QRegularExpression, not QRegExp)
- All HTTP requests are asynchronous via QNetworkAccessManager
- HTML parsing is done with simple string manipulation for QML Label compatibility
- Icons: 86x86, 108x108, 128x128, 256x256
