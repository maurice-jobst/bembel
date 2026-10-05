# ADR 0011 — Widgets fetch for themselves, one download per timeline

Date: 2026-09-26 · Status: accepted

## Context

The rain widget (BEM-F04, #123) needs the RV nowcast at one point. A widget
has two ways to get it. The **app publishes a digest** into the App Group,
the way `CandidateDigest` feeds "Nächster Kandidat". Or the **extension
downloads** the data itself.

A rain forecast is worth something for about an hour. A digest is only as
fresh as the last time somebody opened the app, so the widget would say
"trocken" from yesterday afternoon. That rules out a digest for rain, as long
as the extension can afford the download.

It cannot afford the map's path. `RadolanRadarProvider` inflates the ~130 KB
archive to ~66 MB of tar and parses every frame into 1.3 million cells, and
a widget extension gets roughly 30 MB. Measured on the checked-in fixture
(Linux, release build, peak RSS):

| | peak RSS | over a Foundation-only baseline |
|---|---|---|
| baseline (load the archive, exit) | 25 MB | — |
| `RadolanPointReader` | 32 MB | **+7 MB** |
| `RadolanRadarProvider.nowcast(fromArchive:)` | 115 MB | +90 MB |

## Decision

1. **Extensions fetch for themselves** when their data expires faster than
   people open the app. Digests stay the pattern for data that only the app
   can produce: location, the user's register state.
2. **The extension reads only what it shows.** `RadolanPointReader` streams
   bzip2 in 64 KB chunks and walks the tar as it passes. Of each 2.6 MB
   frame it keeps the nine cells `peak(row:column:)` reads. Its series is held
   equal to the map path's on the real fixture, including a wet cell and the
   grid's clipped corner, and chunk sizes down to 7 bytes are tested.
3. **One download buys a timeline.** The composite already says what each
   five-minute step brings, so `RainWidgetTimeline` writes an entry every
   five minutes, each re-reading the series from its own position. After 60
   minutes a single stale entry says so instead of forecasting.
4. **Reload policy:** `.after(30 min)`, about 48 reloads a day, inside what
   WidgetKit budgets. After a failed download the widget retries after 15
   minutes. The reload interval is half the forecast's lifetime, so a widget
   whose reloads arrive on time never shows the stale state.

## Consequences

- The widget uses the Radar tab's fixed Frankfurt point, not the user's
  location, so it needs no permission and shares nothing through the App
  Group. A widget at the user's position is a later ticket, and it would
  need the app to publish a coordinate, which is exactly the digest pattern
  from point 1.
- Departures (#14) are live data too. When the RMV key arrives, this ADR is
  the default for them: fetch in the extension, one request per timeline.
- Two readers of one format must not drift. The equivalence tests in
  `RadolanPointReaderTests` are what keeps them honest; a change to how the
  map reads a cell changes the point reader in the same PR, or those tests
  go red.
