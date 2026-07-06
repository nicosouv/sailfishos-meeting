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

## Phase 3 — Features

- [ ] Offline mode: read cached meetings without network
- [ ] Notification reminder before the next meeting
- [ ] Global search across all meetings of a year
- [ ] Actions page: aggregate `#action` / `#agreed` items across meetings
- [ ] Filter by participant + participation stats
- [ ] Share meeting link via Sailfish share menu
- [ ] Support years before 2020 (merproject era) or auto-detect available years
- [ ] French translation (only German is declared)
- [ ] "My nick" setting to highlight own mentions in logs
- [ ] Agenda link: surface the forum post announced via `#link`
- [ ] Publish on SailfishOS:Chum (binary lacks `harbour-` prefix, Jolla Store excluded)

## Phase 4 — CI / packaging

- [x] Pin GitHub Actions to commit SHAs (`sailfish-build-rpm`, `action-gh-release`)
