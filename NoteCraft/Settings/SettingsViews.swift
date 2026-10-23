import NoteCraftKit
import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var store: SettingsStore

    var body: some View {
        Form {
            Section(L10n.Settings.windowsSection) {
                Toggle(L10n.Settings.opensDocumentsInTabs, isOn: $store.settings.opensDocumentsInTabs)
                Toggle(isOn: $store.settings.restoresSession) {
                    Text(L10n.Settings.restoresSession)
                    Text(L10n.Settings.restoresSessionHelp)
                }
            }
            Section(L10n.Settings.externalChangesSection) {
                Toggle(isOn: $store.settings.reloadsUnmodifiedDocuments) {
                    Text(L10n.Settings.reloadsUnmodifiedDocuments)
                    Text(L10n.Settings.reloadsUnmodifiedDocumentsHelp)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct EditorSettingsView: View {
    @Bindable var store: SettingsStore
    let fontFamilies: [String]

    init(store: SettingsStore, fontFamilies: [String] = MonospacedFonts.familyNames) {
        self.store = store
        self.fontFamilies = fontFamilies
    }

    var body: some View {
        Form {
            Section(L10n.Settings.fontSection) {
                Picker(L10n.Settings.font, selection: $store.settings.fontName) {
                    Text(L10n.Settings.systemFont).tag(EditorSettings.systemFontName)
                    Divider()
                    ForEach(fontFamilies, id: \.self) { family in
                        Text(family).tag(family)
                    }
                }
                Stepper(value: $store.settings.fontSize, in: EditorSettings.fontSizeRange, step: 1) {
                    LabeledContent(L10n.Settings.fontSize, value: L10n.Settings.points(Int(store.settings.fontSize)))
                }
                Picker(L10n.Settings.lineHeight, selection: $store.settings.lineHeightMultiple) {
                    ForEach([1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.75, 2.0], id: \.self) { value in
                        Text(value.formatted(.number.precision(.fractionLength(1...2)))).tag(value)
                    }
                }
            }
            Section(L10n.Settings.indentationSection) {
                Picker(L10n.Settings.indentWith, selection: $store.settings.indentsWithTabs) {
                    Text(L10n.Settings.spaces).tag(false)
                    Text(L10n.Settings.tabs).tag(true)
                }
                .pickerStyle(.segmented)
                Stepper(value: $store.settings.tabWidth, in: EditorSettings.tabWidthRange) {
                    LabeledContent(L10n.Settings.tabWidth, value: String(store.settings.tabWidth))
                }
                Toggle(L10n.Settings.detectsIndentation, isOn: $store.settings.detectsIndentation)
            }
            Section(L10n.Settings.displaySection) {
                Toggle(L10n.Settings.showsLineNumbers, isOn: $store.settings.showsLineNumbers)
                Toggle(L10n.Settings.highlightsCurrentLine, isOn: $store.settings.highlightsCurrentLine)
                Toggle(L10n.Settings.showsInvisibleCharacters, isOn: $store.settings.showsInvisibleCharacters)
                Toggle(L10n.Settings.wrapsLines, isOn: $store.settings.wrapsLines)
                Toggle(L10n.Settings.highlightsMatchingBrackets, isOn: $store.settings.highlightsMatchingBrackets)
            }
            Section(L10n.Settings.editingSection) {
                Toggle(L10n.Settings.autoIndents, isOn: $store.settings.autoIndents)
                Toggle(L10n.Settings.closesBrackets, isOn: $store.settings.closesBrackets)
                Toggle(L10n.Settings.checksSpelling, isOn: $store.settings.checksSpelling)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ThemeSettingsView: View {
    @Bindable var store: SettingsStore

    var body: some View {
        Form {
            Section {
                themePicker(L10n.Settings.lightTheme, selection: $store.settings.lightThemeID, isDark: false)
                themePicker(L10n.Settings.darkTheme, selection: $store.settings.darkThemeID, isDark: true)
            } footer: {
                Text(L10n.Settings.themesHelp)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func themePicker(_ title: String, selection: Binding<String>, isDark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(title, selection: selection) {
                ForEach(Theme.all.filter { $0.isDark == isDark }) { theme in
                    Text(theme.displayName).tag(theme.id)
                }
            }
            ThemePreview(theme: Theme.theme(withID: selection.wrappedValue) ?? (isDark ? .graphite : .paper))
        }
    }
}

struct ThemePreview: View {
    let theme: Theme

    private var sample: AttributedString {
        var result = AttributedString()
        func append(_ text: String, _ kind: TokenKind?) {
            var part = AttributedString(text)
            part.foregroundColor = kind.map { theme.color(for: $0).color } ?? theme.text.color
            result.append(part)
        }
        append("// ", .comment)
        append(L10n.ThemePreview.comment + "\n", .comment)
        append("let", .keyword)
        append(" count", nil)
        append(": ", nil)
        append("Int", .type)
        append(" = ", nil)
        append("42", .number)
        append("\n", nil)
        append("print", .function)
        append("(", nil)
        append("\"" + L10n.ThemePreview.greeting + "\"", .string)
        append(")", nil)
        return result
    }

    var body: some View {
        Text(sample)
            .font(.system(size: 12, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(theme.background.color, in: .rect(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
            .accessibilityHidden(true)
    }
}

struct MarkdownSettingsView: View {
    @Bindable var store: SettingsStore
    var onResetPermissions: () -> Void = {
        FolderAccessStore.shared.reset()
        ExternalContentStore.shared.reset()
    }

    var body: some View {
        Form {
            Section(L10n.Settings.previewSection) {
                Toggle(L10n.Settings.opensMarkdownPreview, isOn: $store.settings.opensMarkdownPreview)
                Picker(L10n.Settings.scrollSync, selection: $store.settings.markdownScrollSync) {
                    ForEach(MarkdownScrollSync.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }
            Section(L10n.Settings.externalContentSection) {
                Toggle(isOn: $store.settings.loadsExternalContent) {
                    Text(L10n.Settings.loadsExternalContent)
                    Text(L10n.Settings.loadsExternalContentHelp)
                }
                LabeledContent {
                    Button(L10n.Settings.resetPermissions, action: onResetPermissions)
                } label: {
                    Text(L10n.Settings.resetPermissions)
                    Text(L10n.Settings.resetPermissionsHelp)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct FilesSettingsView: View {
    @Bindable var store: SettingsStore

    var body: some View {
        Form {
            Section(L10n.Settings.newDocumentsSection) {
                encodingPicker(L10n.Settings.defaultEncoding, selection: $store.settings.defaultEncoding)
                Picker(L10n.Settings.defaultLineEnding, selection: $store.settings.defaultLineEnding) {
                    ForEach(LineEnding.allCases, id: \.self) { lineEnding in
                        Text(lineEnding.displayName).tag(lineEnding)
                    }
                }
            }
            Section {
                encodingPicker(L10n.Settings.fallbackEncoding, selection: $store.settings.fallbackEncoding)
                Picker(L10n.Settings.largeFileThreshold, selection: $store.settings.largeFileThreshold) {
                    ForEach([1, 5, 10, 25, 50], id: \.self) { megabytes in
                        Text(L10n.Settings.megabytes(megabytes)).tag(megabytes * 1_000_000)
                    }
                }
            } header: {
                Text(L10n.Settings.openingSection)
            } footer: {
                Text(L10n.Settings.fallbackEncodingHelp)
                    .foregroundStyle(.secondary)
            }
            Section(L10n.Settings.savingSection) {
                Toggle(L10n.Settings.trimsTrailingWhitespace, isOn: $store.settings.trimsTrailingWhitespaceOnSave)
                Toggle(L10n.Settings.ensuresTrailingNewline, isOn: $store.settings.ensuresTrailingNewlineOnSave)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func encodingPicker(_ title: String, selection: Binding<TextEncoding>) -> some View {
        Picker(title, selection: selection) {
            ForEach(Array(TextEncoding.menuGroups.enumerated()), id: \.offset) { index, group in
                if index > 0 {
                    Divider()
                }
                ForEach(group, id: \.self) { encoding in
                    Text(encoding.displayName).tag(encoding)
                }
            }
        }
    }
}
