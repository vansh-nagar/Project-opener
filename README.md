# Project Opener

A Spotlight-style launcher for your code projects.

Press **⌥⌘O**, type a few letters, hit **Enter** — the project opens in Cursor.

Native SwiftUI in a floating panel. ~500 KB, no dependencies, no Electron, no
background runtime. Opens in well under a second.

```
        ┌────────────────────────────────────────────────┐
        │  🔍  api                                       │
        ├────────────────────────────────────────────────┤
        │  PINNED                                        │
        │  📁  api-server        work/acme/api-server  ⭐ │
        │                                                │
        │  ALL PROJECTS                                  │
        │  📁  api-docs          work/acme/api-docs      │
        │  📁  rapid-proto       personal/rapid-proto    │
        └────────────────────────────────────────────────┘
```

---

## Requirements

- macOS 14 or later
- Xcode or the Swift toolchain (`swift --version` should work)
- [Cursor](https://cursor.com) or VS Code

## Install

```sh
git clone https://github.com/vansh-nagar/Project-opener.git
cd Project-opener
./build.sh --install
```

That builds a release binary, assembles `ProjectOpener.app`, copies it to
`/Applications`, and launches it.

There's no Dock icon — it's a menu bar app. Look for the folder-and-gear icon in
your menu bar to confirm it's running.

Drop the `--install` flag to just build `./ProjectOpener.app` locally without
touching `/Applications`.

## First run — point it at your code

**This is the step people miss.** Out of the box it scans `~/Desktop/mvp/dev`,
which almost certainly isn't where your projects live. If the panel comes up
empty, that's why.

Open `~/Library/Application Support/ProjectOpener/config.json` (menu bar →
**Edit Config…**) and set `roots` to your own folders:

```json
{
  "roots": ["~/Developer", "~/work"]
}
```

Then menu bar → **Reload Config**. You should see your projects immediately.

To check what it found without opening the UI:

```sh
./.build/release/ProjectOpener --scan
```

## Using it

Press **⌥⌘O** anywhere. Start typing. Hit Enter.

| Key | Action |
| --- | --- |
| `⌥⌘O` | Show / hide the panel (works from any app) |
| `↑` `↓` | Move selection — `⌃P` / `⌃N` also work |
| `Return` | Open the selected project in Cursor |
| `⌘P` | Pin / unpin — pinned projects sort to the top |
| `⌘R` | Rescan for new projects |
| `Esc` | Dismiss |

Clicking anywhere outside the panel dismisses it too.

With an empty search box you get three groups: **Pinned**, **Recent** (the last
12 you opened), then **All Projects**. Start typing and it collapses to a single
ranked list.

### Searching

Matching is subsequence-based, so you don't need whole words — the letters just
have to appear in order:

| You type | It finds | Why |
| --- | --- | --- |
| `apisrv` | `api-server` | skips letters freely |
| `dsgn` | `design-system` | initials work |
| `acme` | `work/acme/api-server` | matches the path, not just the name |

Folder-name matches outrank path-only matches, so typing a project's actual name
always wins. Matches on word boundaries (after `-`, `_`, `/`, or a camelCase
hump) score higher than matches mid-word, and consecutive letters score higher
than scattered ones. Pinned and recently-opened projects get a boost.

Matched letters are highlighted in the results so you can see why something
ranked where it did.

### Keeping it running

The app doesn't survive a reboot on its own. To start it at login:

**System Settings → General → Login Items → +** → add
`/Applications/ProjectOpener.app`.

## What counts as a project

Each root is walked up to `maxDepth` levels deep. A directory is a project if it
contains any of:

- `.git`
- `package.json`, `Package.swift`, `Cargo.toml`, `go.mod`, `pyproject.toml`,
  `requirements.txt`, `Gemfile`
- anything ending in `.xcodeproj` or `.xcworkspace`

Once a directory matches, it's recorded and **not** descended into — so a repo
vendored inside another repo doesn't show up as a duplicate. `node_modules`,
`.next`, `build`, `dist`, `target`, `Pods`, `.venv` and similar are skipped
entirely, which is what keeps the scan fast.

Nesting depth doesn't matter. `work/acme/api-server` and
`personal/tools/cli/parser` are both found and both display their full relative
path, so same-named projects in different folders stay distinguishable.

## Config

`~/Library/Application Support/ProjectOpener/config.json`, written on first run.
Edit it, then choose **Reload Config** from the menu bar.

```json
{
  "roots": ["~/Developer"],
  "maxDepth": 5,
  "hotkey": "cmd+opt+o",
  "editorBundleIDs": [
    "com.todesktop.230313mzl4w4u92",
    "com.microsoft.VSCode"
  ],
  "hideOnBlur": true
}
```

| Key | What it does |
| --- | --- |
| `roots` | Folders to scan. `~` is expanded. Add as many as you like. |
| `maxDepth` | How deep to walk each root. Raise it if projects are buried. |
| `hotkey` | `cmd`, `opt`, `ctrl`, `shift` + a letter, digit, or `space`. Needs at least one modifier. |
| `editorBundleIDs` | Tried in order; first installed one wins. Default is Cursor, then VS Code. |
| `hideOnBlur` | `false` keeps the panel open when it loses focus. |

Editors launch through `NSWorkspace` and a bundle ID rather than a shell
command, so there's no `PATH` setup — the `cursor` CLI isn't on `PATH` by
default and shelling out to it would fail.

Pins and recents live beside it in `state.json`.

### Using a different editor

Find its bundle ID, then put it first in `editorBundleIDs`:

```sh
osascript -e 'id of app "Zed"'
```

## Troubleshooting

**The panel is empty.** Your `roots` are wrong — see [First run](#first-run--point-it-at-your-code).
Run `--scan` to see what it's actually finding.

**⌥⌘O does nothing.** Another app already owns that shortcut. Project Opener
shows a warning at launch when registration fails. Pick a different `hotkey` in
`config.json` and **Reload Config**. You can always open the panel from the menu
bar icon.

**A new project doesn't appear.** Press `⌘R`, or menu bar → **Rescan Projects**.
It also rescans automatically when the panel opens, throttled to once every 30
seconds.

**Nothing in the menu bar.** It isn't running — `open /Applications/ProjectOpener.app`.

## How it works

The panel is a non-activating `NSPanel` that can join all Spaces and float over
fullscreen apps, so it appears without disturbing what you were doing.

The global hotkey uses Carbon's `RegisterEventHotKey`, which — unlike
`NSEvent.addGlobalMonitorForEvents` — needs **no Accessibility permission**. The
app asks for no permissions at all.

Scanning runs off the main thread, so the panel is interactive immediately and
fills in as results arrive.

## Debugging

```sh
./.build/release/ProjectOpener --scan          # list every project found
./.build/release/ProjectOpener --match api     # ranked results with scores

# verbose logging to stderr
PROJECTOPENER_DEBUG=1 ./ProjectOpener.app/Contents/MacOS/ProjectOpener

# open the panel immediately on launch
PROJECTOPENER_SHOW_ON_LAUNCH=1 ./ProjectOpener.app/Contents/MacOS/ProjectOpener
```

## Source layout

| File | Role |
| --- | --- |
| `Scanner.swift` | Walks the roots, prunes junk, detects project roots |
| `Fuzzy.swift` | Subsequence matcher — DP with backtrace, returns match indices |
| `Ranker.swift` | Scores projects against a query; pure and testable |
| `Store.swift` | Pins + recents, persisted as JSON |
| `Config.swift` | Settings and hotkey string parsing |
| `HotKey.swift` | Carbon `RegisterEventHotKey` |
| `PanelController.swift` | The panel, focus, key handling, dynamic sizing |
| `SearchView.swift` | SwiftUI list with match highlighting |
| `Opener.swift` | Resolves the editor and opens the folder |
| `AppModel.swift` | Search state, result grouping, actions |
