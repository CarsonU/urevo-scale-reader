# UREVO iOS App

Native SwiftUI iPhone app for recording UREVO scale readings over BLE.

## Project Layout

- `UrevoScale/` app source
- `UrevoScaleTests/` unit and integration tests
- `UrevoScale.xcodeproj` generated Xcode project
- `scripts/generate_project.rb` regenerates the project file from source layout

## Open and Run

1. Open `/Users/carson/Projects/urevo/urevo-ios/UrevoScale.xcodeproj` in Xcode.
2. In target `UrevoScale`, choose your Apple team in Signing.
3. Build and run on an iPhone (Bluetooth + HealthKit features require device testing).

## Notes

- Uses SwiftData for local persistence (`WeightEntry`).
- Writes optional body-mass samples to HealthKit.
- CSV import/export is compatible with `timestamp,weight_lbs`.
- Scale protocol decoder mirrors `/Users/carson/Projects/urevo/urevo-python/scale_reader.py`.
