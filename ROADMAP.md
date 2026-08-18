# Roadmap

## Phase 1 — Security & correctness

- [x] Escape IRC content before rendering as StyledText (markup/link injection in log view)
- [x] Fix memory leak: parsed objects (Meeting, IrcMessage, MeetingTopic, MeetingStatistics) are never freed
- [x] Scope `htmlContentLoaded` signal by URL (summary page parses log content when both pages are stacked)
- [x] Clear stored next meeting date once it is in the past (cover shows stale date)
- [x] Write ICS file to app cache directory instead of hardcoded `/tmp` path
- [x] Deduplicate next-meeting regex, remove unused code, handle loading state in `fetchHtmlContent`

## Phase 2 — Performance

- [x] Hoist regex compilation out of per-line parsing loop
- [x] Cache favorites/read status in memory (avoid QSettings reads in every delegate binding)
- [x] Debounce message search
- [x] Add QNetworkDiskCache (conditional GETs, 304 served from cache)
- [ ] QAbstractListModel for large logs (needs build environment to validate)
- [x] Year scan downloads in parallel and can be cancelled

## Phase 3 — Features

- [x] Offline mode: cached content is served when the network is unavailable
- [x] Meeting reminder via calendar alarm (VALARM 30 min before) in the ICS export
- [x] Global search across all meetings of a year
- [x] Actions page: aggregate `#action` / `#agreed` items across meetings
- [x] Filter log messages by participant (tap avatar/username)
- [x] Copy meeting link to clipboard
- [x] Auto-detect available years from the server index
- [x] French translation, refreshed German translation
- [x] "My nick" setting to highlight own mentions in logs
- [x] Agenda link: surface the forum thread found in the latest log
- [x] Meeting summary page (action items, decisions, attendance) with deep links into the log
- [x] Selectable display styles for meeting notes and conversation
- [x] Mer meeting logs (2011-2020)
- [x] Storage usage and data clearing in the settings
- [ ] Publish on SailfishOS:Chum (external submission; binary lacks `harbour-` prefix, Jolla Store excluded)

## Phase 4 — CI / packaging

- [x] Pin GitHub Actions to commit SHAs (`sailfish-build-rpm`, `action-gh-release`)

## Phase 5 — Tests

- [x] Parser tests on frozen meetbot fixtures, gating the RPM build in CI
