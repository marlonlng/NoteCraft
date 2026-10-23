# Contributing to NoteCraft

Thanks for your interest in NoteCraft. Bug reports, translations and pull requests are welcome.

## Before you start

- For larger changes, open an issue first so we can agree on the direction.
- NoteCraft is a focused, native Mac editor. Plugin systems, cross-platform UI and features that need network access or collect data are out of scope.

## Building

1. Install Xcode 27 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen).
2. Run `xcodegen generate` after changing `project.yml` or adding files.
3. Open `NoteCraft.xcodeproj` and run the **NoteCraft** scheme.

Debug builds are signed ad hoc and need no Apple Developer account. Release builds need your own team: copy `Config/Local.example.xcconfig` to `Config/Local.xcconfig` and set `DEVELOPMENT_TEAM` and `NOTECRAFT_BUNDLE_ID_PREFIX`. `Config/Local.xcconfig` is ignored by Git.

## Tests

```bash
xcodebuild test -scheme NoteCraft -destination 'platform=macOS'
xcodebuild test -scheme NoteCraftUITests -destination 'platform=macOS'
```

- Unit tests use Swift Testing, UI tests use XCTest.
- Add or update tests for every change. Line coverage of the app and NoteCraftKit stays between 75 and 85 %.
- Tests run in English. The UI tests take control of mouse and keyboard while they run.

## Conventions

- **Language:** code, comments, tests and commit messages are in English.
- **User interface:** every visible text goes through `L10n` (`NoteCraft/Support/L10n.swift`) with English as the source language. Add the German translation to `NoteCraft/Resources/Localizable.xcstrings` in the same change.
- **Comments:** no comments in code, except documentation comments on functions.
- **Domain terms:** use the terms that already exist in the code and the interface, such as *document*, *encoding*, *line ending* and *find bar*. Don't introduce synonyms.
- **Platform:** follow the [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines) and prefer system controls, menus and shortcuts.
- **Commit messages:** a single subject line in past tense that starts with a capitalized verb, for example `Added bookmark gutter`. No body, no trailers.

## Translations

The interface is available in English and German. To add a language, open `NoteCraft/Resources/Localizable.xcstrings` and `NoteCraft/Resources/InfoPlist.xcstrings` in Xcode, add the language and translate every string. Keep format specifiers such as `%lld` and `%@` intact; `LocalizationTests` checks them.

## Pull requests

- Keep each pull request to one topic.
- Make sure the project builds without warnings and all tests pass.
- Describe what changed and how you tested it.

By contributing, you agree that your contributions are licensed under the [Apache License 2.0](LICENSE).
