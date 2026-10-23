# NoteCraft

A fast, native plain-text and source-code editor for macOS. NoteCraft takes the strengths of Notepad++ and rethinks them as an independent Mac app. The interface is available in English and German.

## Highlights

- **Nothing gets lost:** untitled and unsaved documents survive quitting and come back at launch; autosave and Versions included.
- **Encodings under control:** detection (BOM, UTF-8, UTF-16 heuristic, declared charsets), *Reopen with Encoding* and *Convert to Encoding*, and a lossy-save check that names the character, line and column.
- **Line endings:** LF, CRLF and CR detection, conversion and an indicator for mixed line endings.
- **Search:** find bar with live match count, regular expressions with inline validation and a cheat sheet, replace with `$1` templates, and Find in Files across a folder with glob patterns.
- **Editing:** syntax highlighting for 32 languages, line numbers, current-line and bracket highlighting, invisible characters, multiple cursors and column selection, select next/all occurrences, auto-indent, auto-closing pairs, comment toggling, line operations and text transformations (case, Base64, URL, HTML, order-preserving JSON).
- **Mac-native:** document-based AppKit app with native tabs, Liquid Glass toolbar and sidebar, command palette (⇧⌘A), Open Quickly (⇧⌘O), a Settings window, built-in help and light, dark and high-contrast themes.
- **Private:** no accounts, no tracking, no network access. NoteCraft runs in the App Sandbox and only opens files and folders you choose. See the [privacy policy](PRIVACY.md).

## Requirements

- macOS 26 or later
- Xcode 27 or later, Swift 6 with strict concurrency
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to regenerate the project from `project.yml`

## Build and run

```bash
git clone https://github.com/marlonlng/NoteCraft.git
cd NoteCraft
xcodegen generate
open NoteCraft.xcodeproj
```

Run the **NoteCraft** scheme with ⌘R. Debug builds are signed ad hoc and need no Apple Developer account.

For release builds, copy `Config/Local.example.xcconfig` to `Config/Local.xcconfig` and set your own `DEVELOPMENT_TEAM` and `NOTECRAFT_BUNDLE_ID_PREFIX`. The file is ignored by Git.

## Tests

```bash
xcodebuild test -scheme NoteCraft -destination 'platform=macOS'
xcodebuild test -scheme NoteCraftUITests -destination 'platform=macOS'
```

The first command runs the unit tests of the app and NoteCraftKit, the second runs the end-to-end UI tests. The UI tests take control of mouse and keyboard while they run.

## Localization

English is the source language; German is a full translation. All interface texts live in `NoteCraft/Support/L10n.swift`, translations in `NoteCraft/Resources/Localizable.xcstrings` and `NoteCraft/Resources/InfoPlist.xcstrings`. New languages are welcome, see [CONTRIBUTING.md](CONTRIBUTING.md).

## Project structure

| Path | Content |
| --- | --- |
| `NoteCraftKit/` | Framework with the domain logic: encodings, line endings, line index, search, file search, text transformations, syntax highlighting, themes, settings |
| `NoteCraft/` | AppKit and SwiftUI app: document, editor, find bar, status bar, sidebar, command palette, settings, help, menu bar |
| `NoteCraftKitTests/`, `NoteCraftTests/` | Unit tests (Swift Testing) |
| `NoteCraftUITests/` | End-to-end UI tests (XCTest) and screenshot capture |
| `Config/` | Shared build settings and the template for local signing settings |
| `Scripts/` | App icon generation, screenshot composition and App Store export options |

## Assets

```bash
swift Scripts/GenerateAppIcon.swift NoteCraft/Resources/Assets.xcassets/AppIcon.appiconset
swift Scripts/ComposeAppStoreScreenshots.swift <screenshot folder> <output folder> <captions.json>
```

The raw screenshots come from the `AppStoreScreenshotTests` UI test. The captions file is a JSON array of objects with `file`, `headline` and `subline`.

## Contributing

Bug reports, questions, translations and pull requests are welcome in the [issues](https://github.com/marlonlng/NoteCraft/issues). Please read [CONTRIBUTING.md](CONTRIBUTING.md) first and report security issues as described in [SECURITY.md](SECURITY.md).

## License

NoteCraft is licensed under the [Apache License 2.0](LICENSE).

The name “NoteCraft” and the NoteCraft app icon are not covered by this license.
