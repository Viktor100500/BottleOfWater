# Bottle of Water

A water tracker for iPhone: one-tap logging from the app, widgets, Control Center, Siri and reminders, with Apple Health sync. iOS 18+, SwiftUI, SwiftData, WidgetKit, App Intents. No accounts, no network, no analytics.

## Project

The Xcode project is generated from `project.yml`:

```bash
brew install xcodegen
xcodegen generate
open BottleOfWater.xcodeproj
```

| Path | What |
|---|---|
| `App/` | App target: tabs (Today, History, Settings), onboarding, entry editor, reminders UI |
| `Widget/` | Home/Lock Screen widgets and the Control Center control |
| `Shared/Core` | Pure logic: units, settings, reminder planning, history statistics |
| `Shared/Data` | SwiftData model and `WaterStore` — the single write path for every log |
| `Shared/Services` | Apple Health sync (write-only, sync identifiers) and notification scheduling |
| `Shared/Intents` | App Intents for Siri, Shortcuts, widget and control buttons |
| `Tests/` | Swift Testing unit tests for the core logic |
| `site/` | Support and privacy pages (GitHub Pages) |
| `docs/` | Audit and requirements, release checklist, App Store metadata and screenshots |
| `scripts/` | Icon and App Store screenshot generators |

## How a log flows

`WaterStore.add` (called by the app, a widget button, a Control Center control, Siri or a notification action):

1. saves the entry to the shared SwiftData store and reloads widgets;
2. writes it to Apple Health with `HKMetadataKeySyncIdentifier` — retries and edits replace the sample instead of duplicating it; failures stay pending and are retried on launch, activation and background refresh;
3. reschedules reminders (interval restarts from the last drink, pauses after the goal);
4. pings the running app over a Darwin notification so it refreshes immediately.

## Tests

```bash
xcodebuild test -project BottleOfWater.xcodeproj -scheme BottleOfWater -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Screenshots

Debug builds accept launch arguments for demo data: `-demoData YES -screen today|add|history|reminders -range month -amount 350`. Capture with `xcrun simctl io <device> screenshot`, then compose with `python3 scripts/make_screenshots.py <raw> docs/app-store/screenshots`.

## Release

See [docs/RELEASE.md](docs/RELEASE.md).
