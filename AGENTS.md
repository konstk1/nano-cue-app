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

## Timer Behavior
- Lead-in defaults to 3 seconds. The lead-in −/+ controls decrease/increase it in 1-second steps, from 0s to 60s.
- Set duration defaults to 40 seconds and changes in 5-second steps (5–600 seconds).
- Lead-in and interval controls lock after Start, including while paused; Reset stops and restores the chosen lead-in.
- Lead-in time does not count toward sets. Set 1 begins at zero; each complete duration advances the set number.
- Each bar represents one set: set 1 fills one bar, set 2 fills two, and so on, including during lead-in. Add rows of ten as needed; bars do not show elapsed progress.
- Play only a tick at zero (including an immediate start with no lead-in), then retain the existing 5-second ticks and 10-second/minute speech cues.
- Timer tests use an injected clock and disabled audio for deterministic pause, resume, reset, and boundary checks.
- Set counting defaults on and can be toggled at any time. Off shows a dash, clears the set bars, and disables interval edits.
- Toggling preserves elapsed time and interval; enabling again derives sets from total elapsed time since zero. Reset preserves the toggle.
- Interval −/+ buttons use the full 44×48-point segment as their hit target, including blank space around the symbols.
