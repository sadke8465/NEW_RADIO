# NewRadio

A small, minimalistic internet-radio app for macOS. SwiftUI. Keyboard-first.
Browses stations from the free [Radio-Browser](https://www.radio-browser.info) API.

Feels like a terminal. Looks like a widget.

---

## Features

- Top stations, name search, genres, favorites, recents
- Pure keyboard navigation (vim-style + arrows)
- Persistent favorites and play history (UserDefaults)
- Ad-hoc signed, no API key
- Small resizable window (~380×560) with translucent Apple chrome

## Keybindings

| key | action |
|-----|--------|
| `1` … `4` | switch section (top / tags / stars / recent) |
| `←` / `→` | switch section (previous / next) |
| `↑` / `↓` | move list selection |
| `j` | move selection down |
| `k` | move selection up |
| `g g` | jump to top |
| `G` | jump to bottom |
| `↵` or `space` | play selected station |
| `p` | toggle play / pause |
| `.` | stop |
| `f` | star / unstar selected station |
| `F` | star / unstar the *currently playing* station |
| `S` or `/` | open search & focus input |
| `−` / `=` | volume down / up |
| `v` | toggle visualizer |
| `esc` | back out (close help → clear filter → clear search) |
| `?` | toggle help overlay |
| `⌘W` / `⌘Q` | standard macOS close / quit |

## Build

Requires macOS 14+ with Xcode Command Line Tools.

```bash
./build.sh
open build/NewRadio.app
```

Or via Swift Package Manager for dev:

```bash
swift run
```

(SPM mode skips the `.app` bundle but still launches the SwiftUI window.)

## Project layout

```
Sources/
  NewRadioApp.swift      entry point, window styling
  AppState.swift         top-level ObservableObject, modes, signals
  RadioBrowserAPI.swift  API client + Station/RadioTag models
  AudioPlayer.swift      AVPlayer wrapper, volume, buffering
  FavoritesStore.swift   persists favorites & recents
  ContentView.swift      layout + global keyboard shortcut mounts
  Chrome.swift           header, tab strip, now-playing bar, help overlay
  StationList.swift      reusable keyboard-navigable list
  ModeViews.swift        one view per tab
  Visualizer.swift       audio visualizer (settings, presets, driver)
Resources/
  Info.plist
build.sh                 swiftc -> .app bundle
Package.swift            `swift run` for dev
```

## Notes

- Streams are fetched straight from Radio-Browser; many are plain HTTP, so
  `NSAllowsArbitraryLoads` is set in `Info.plist`.
- No sandbox entitlements — add them if you plan to distribute.
