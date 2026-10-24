# Night Sky

A tiny SwiftUI test app: twinkling stars, a crescent moon, and shooting stars (tap anywhere to launch one). iOS 15+.

## Getting the IPA

Pushing to GitHub runs `.github/workflows/build-ipa.yml` on a macOS runner. It generates the Xcode project with XcodeGen, builds without code signing, and packages `Payload/NightSky.app` into `NightSky.ipa`.

Download it from the run page (Actions → latest run → Artifacts → `NightSky-ipa`), unzip it once to get `NightSky.ipa`, then import and sign it in Feather.

Bundle ID: `com.example.nightsky` (Feather can override it when signing).
