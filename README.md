# Project Opener

A Spotlight-style launcher for your projects. Press **⌥⌘O**, type a few letters,
hit Enter — the project opens in Cursor.

Native SwiftUI. ~500 KB, no runtime, no dependencies.

```
┌──────────────────────────────────────────┐
│  🔍  sarj                                │
├──────────────────────────────────────────┤
│  ⌘  bulbul            office/sarj/bulbul │
│     Best Mockup   office/sarj/Best Mockup│
└──────────────────────────────────────────┘
```

## Install

```sh
./build.sh --install     # builds, copies to /Applications, launches
```

The app lives in the menu bar (no Dock icon). Use the menu bar icon to rescan,
edit config, or quit.

To have it start at login: System Settings → General → Login Items → add
`/Applications/ProjectOpener.app`.

## Keys

| Key | Action |
| --- | --- |
| `⌥⌘O` | Show / hide the panel (global) |
| `↑` `↓` | Move selection (also `⌃P` / `⌃N`) |
| `Return` | Open in Cursor |
| `⌘P` | Pin / unpin the selected project |
| `⌘R` | Rescan now |
| `Esc` | Dismiss |

Clicking away dismisses the panel too.

## How projects are found

Directories under each root are walked up to `maxDepth`. A directory counts as a
project when it contains any of:

- `.git`
- `package.json`, `Package.swift`, `Cargo.toml`, `go.mod`, `pyproject.toml`,
  `requirements.txt`, `Gemfile`
- anything ending in `.xcodeproj` / `.xcworkspace`

Once a directory matches it is recorded and **not** descended into, so a repo
nested inside another repo doesn't produce duplicate noise. `node_modules`,
`.next`, `build`, `target`, `Pods` and friends are skipped entirely.

Search matches the folder name first and falls back to the full relative path, so
`bulbul` and `sarj` both find `office/sarj/bulbul`. Matching is subsequence-based
(`icnsp` → `icon-space-main`), scored with bonuses for word boundaries and
consecutive runs. Pinned and recent projects get a ranking boost.

## Config

`~/Library/Application Support/ProjectOpener/config.json` — written on first run.
Edit it, then pick **Reload Config** from the menu bar.

```json
{
  "roots": ["~/Desktop/mvp/dev"],
  "maxDepth": 5,
  "hotkey": "cmd+opt+o",
  "editorBundleIDs": [
    "com.todesktop.230313mzl4w4u92",
    "com.microsoft.VSCode"
  ],
  "hideOnBlur": true
}
```

- **roots** — folders to scan. Add more, or narrow to
  `["~/Desktop/mvp/dev/personal", "~/Desktop/mvp/dev/office"]` to skip college
  coursework and freelance work.
- **hotkey** — `cmd`, `opt`, `ctrl`, `shift` plus a letter, digit, or `space`.
  Needs at least one modifier.
- **editorBundleIDs** — tried in order; the first installed one wins. Cursor,
  then VS Code. Editors are launched through `NSWorkspace`, not a shell, so no
  `PATH` setup is needed (the `cursor` CLI is not on `PATH` by default).
- **hideOnBlur** — set `false` to keep the panel open when it loses focus.

Pins and recents live next door in `state.json`.

## Debugging

```sh
./.build/release/ProjectOpener --scan            # list every project found
./.build/release/ProjectOpener --match sarj      # show ranked results + scores

PROJECTOPENER_DEBUG=1 ./ProjectOpener.app/Contents/MacOS/ProjectOpener
PROJECTOPENER_SHOW_ON_LAUNCH=1 ...               # open the panel immediately
```

## Layout

| File | Role |
| --- | --- |
| `Scanner.swift` | Walks the roots, prunes junk, detects project roots |
| `Fuzzy.swift` | Subsequence matcher (DP + backtrace, returns match indices) |
| `Ranker.swift` | Scores projects against a query; pure, testable |
| `Store.swift` | Pins + recents, persisted as JSON |
| `Config.swift` | Settings, hotkey string parsing |
| `HotKey.swift` | Carbon `RegisterEventHotKey` — no Accessibility permission |
| `PanelController.swift` | Non-activating `NSPanel`, focus, key handling, sizing |
| `SearchView.swift` | SwiftUI list, match highlighting |
| `Opener.swift` | Resolves the editor and opens the folder |
