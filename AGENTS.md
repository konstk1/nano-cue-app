# Repository Guidelines

## Project Structure & Modules
- `NanoCue/`: SwiftUI app code (`NanoCueApp.swift`, `ContentView.swift`, `CuedTimer.swift`), assets in `Assets.xcassets`, audio in `Tink.aiff`.
- `NanoCueTests/`: Unit tests (XCTest).
- `NanoCueUITests/`: UI tests (XCTest UI).
- `NanoCue.xcodeproj/`: Xcode project and schemes.

## Build, Test, and Run
- Open in Xcode: `open NanoCue.xcodeproj`, select the `NanoCue` scheme, Run to launch on Simulator.
- CLI build (Simulator): `xcodebuild -project NanoCue.xcodeproj -scheme NanoCue -configuration Debug -destination 'generic/platform=iOS Simulator' build`.
- CLI tests: `xcodebuild -project NanoCue.xcodeproj -scheme NanoCue -destination 'platform=iOS Simulator,name=iPhone 15' test`.

### Xcode Version (iOS 26 toolchain)
- This project targets iOS 26 APIs. Use Xcode 16 beta.
- CLI builds should select Xcode-beta explicitly:
  - `DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer" xcodebuild -project NanoCue.xcodeproj -scheme NanoCue -configuration Debug -destination 'generic/platform=iOS Simulator' build`

## Coding Style & Naming
- Swift 6, 4‑space indentation; keep lines ≲120 chars.
- Types: UpperCamelCase; methods/properties: lowerCamelCase; enum cases: lowerCamelCase.
- One primary type per file; file name matches type (e.g., `CuedTimer.swift`).
- View structs end with `View` (e.g., `ContentView`); extension files use `Type+Feature.swift` when helpful.
- Prefer `struct` over `class` when possible; mark classes `final` unless subclassing.

## Testing Guidelines
- Framework: XCTest. Unit tests in `NanoCueTests`, UI tests in `NanoCueUITests`.
- File naming: `ThingTests.swift`; methods: `test...()` with clear Arrange/Act/Assert.
- Keep tests deterministic (use `XCTestExpectation` for timers/async).
- Run via Xcode Product > Test or the CLI test command above.

## Commit & PR Guidelines
- Commits use imperative mood and stay focused (e.g., "Fix duplicate announcements").
- Include a short body when rationale isn’t obvious.
- PRs include: description, linked issues, screenshots/screencasts for UI changes, and notes on tests.
- Ensure the app builds and all tests pass locally before requesting review.

## Security & Config Tips
- Update `Info.plist` when adding capabilities/permissions (e.g., audio/background).
- Do not commit signing files, provisioning profiles, or secrets. Keep bundle IDs/signing config local.

## Agent‑Specific Notes
- Follow the structure above; avoid sweeping refactors.
- When altering public APIs or behaviors, update tests and this guide accordingly.
