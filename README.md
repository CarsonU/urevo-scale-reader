# UREVO iOS App

Native SwiftUI iPhone app for recording UREVO scale readings over BLE.

## Features

- Connects to a UREVO Bluetooth scale and captures stable weight readings automatically
- Logs weight history with SwiftData persistence
- Trends page with configurable range presets and outlier filtering
- Export weight entries to Apple Health as body-mass samples
- CSV import/export (`timestamp,weight_lbs` format)
- lbs / kg display unit toggle
- Onboarding flow for first launch

## Project Layout

```
UrevoScale/
  App/            App entry point
  Models/         SwiftData models and supporting types
  Services/       BLE, HealthKit, CSV, persistence, and protocol decoding
  Store/          App-wide state (AppStateStore)
  Utilities/      Formatters and defaults
  Views/          All SwiftUI screens
UrevoScaleTests/  Unit and integration tests
UrevoScale.xcodeproj
scripts/generate_project.rb   Regenerates the project file from source layout
```

## Open and Run

1. Clone the repo and open `UrevoScale.xcodeproj` in Xcode.
2. In the `UrevoScale` target, select your Apple team under **Signing & Capabilities**.
3. Build and run on a physical iPhone — Bluetooth and HealthKit require a real device.

## Notes

- Bluetooth scanning uses CoreBluetooth; no third-party BLE library.
- HealthKit writes are optional and prompt for permission on first use.
- Scale wire protocol is decoded in `Services/ScaleProtocolDecoder.swift`.
