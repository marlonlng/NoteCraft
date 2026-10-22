# NoteCraft

A fast, native plain-text and source-code editor for macOS, inspired by the strengths of Notepad++ and built as an independent Mac product. The user interface is German.

![Editor](AppStore/Screenshots/de-DE/01-Editor.png)

## Highlights

- **Nothing gets lost:** untitled and unsaved documents survive quitting and come back at launch; autosave and Versions included.
- **Encodings under control:** detection (BOM, UTF-8, UTF-16 heuristic, declared charsets), *Erneut öffnen mit* / *Konvertieren in*, lossy-save validation naming character, line and column.
- **Line endings:** LF, CRLF and CR detection, conversion and a mixed-line-ending indicator.
- **Search:** find bar with live match count, regular expressions with inline validation and cheat sheet, replace with `$1` templates, file search across a folder with glob patterns.
- **Editing:** syntax highlighting for 33 languages, line numbers, current-line and bracket highlighting, invisible characters, multi-cursor and column editing, select next/all occurrences, auto-indent, auto-closing pairs, comment toggling, line operations and text transformations (case, Base64, URL, HTML, order-preserving JSON).
- **Mac-native:** document-based AppKit app with native tabs, Liquid Glass toolbar and sidebar, command palette (⇧⌘A), Open Quickly (⇧⌘O), Settings window, Help with shortcuts, light/dark/high-contrast themes.

## Requirements

- macOS 26 or later
- Xcode 27, Swift 6 (strict concurrency)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to regenerate the project from `project.yml`

## Project structure

| Path | Content |
| --- | --- |
| `NoteCraftKit/` | Framework with the domain logic: encodings, line endings, line index, search, file search, text transformations, syntax highlighting, themes, settings |
| `NoteCraft/` | AppKit/SwiftUI app: document, editor, find bar, status bar, sidebar, command palette, settings, help, menu bar |
| `NoteCraftKitTests/`, `NoteCraftTests/` | Unit tests (Swift Testing) |
| `NoteCraftUITests/` | End-to-end UI tests (XCUITest) and App Store screenshot capture |
| `Scripts/` | App icon generation and App Store screenshot composition |
| `AppStore/` | Screenshots, German metadata, privacy policy, release checklist |
| `docs/` | Research summary and glossary of domain terms |

## Build and test

```bash
xcodegen generate
xcodebuild build -scheme NoteCraft -destination 'platform=macOS'
xcodebuild test -scheme NoteCraft -destination 'platform=macOS'
xcodebuild test -scheme NoteCraftUITests -destination 'platform=macOS'
```

Unit test coverage (NoteCraft.app + NoteCraftKit.framework): **82.5 %** (app 77.1 %, framework 98.3 %).
The UI tests take control of mouse and keyboard while they run.

## Assets

```bash
swift Scripts/GenerateAppIcon.swift NoteCraft/Resources/Assets.xcassets/AppIcon.appiconset
swift Scripts/ComposeAppStoreScreenshots.swift build/screenshots AppStore/Screenshots/de-DE
```

The raw screenshots come from the `AppStoreScreenshotTests` UI test (attachments of its result bundle).

## Conventions

- Code, commits and tests in English; UI texts and validation messages in German (`NoteCraft/Support/L10n.swift`).
- Domain terms are defined once in [docs/Glossary.md](docs/Glossary.md); no synonyms.
- No comments in code except function doc comments.
- Short past-tense commit subjects without body or trailers.

## Release

See [AppStore/ReleaseChecklist.md](AppStore/ReleaseChecklist.md).
