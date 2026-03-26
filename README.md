# OnAir

A lightweight macOS menu bar app that keeps your meetings always visible. No Electron, no accounts, no bloat.

## Install

```bash
brew tap chaiovercode/tap
brew install --cask on-air
```

Or download the latest `.zip` from [Releases](https://github.com/chaiovercode/on-air/releases), unzip, and drag to Applications.

## Features

- **Menu bar countdown** -- see your next meeting and time remaining at a glance
- **Today timeline** -- visual day view with drag-to-reschedule
- **Focus timer** -- calendar-aware deep work blocks that fit between meetings
- **Conflict detection** -- overlapping meetings get flagged automatically
- **Auto-join** -- one-click join for Zoom, Meet, and Teams links
- **Wrap-up alerts** -- configurable heads-up before meetings end
- **Natural language events** -- type "lunch with Raj tomorrow at 1pm for 1h" and it just works
- **Meeting stats** -- weekly activity, contribution graph, top people, peak hours
- **World clock** -- up to 4 timezone clocks in the panel
- **Keyboard first** -- `J` to join, `T` for timeline, `Cmd+N` for new event

## Requirements

- macOS 13+
- Calendar access (prompted on first launch)

## Build from source

```bash
git clone https://github.com/chaiovercode/on-air.git
cd on-air
make build
```

The built app will be in `build/Build/Products/Debug/OnAir.app`.

## License

MIT
