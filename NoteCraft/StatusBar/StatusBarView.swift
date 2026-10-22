import NoteCraftKit
import SwiftUI

struct StatusBarView: View {
    let model: StatusBarModel
    let attributes: DocumentAttributes
    let canReopen: Bool
    weak var actions: StatusBarActions?

    var body: some View {
        HStack(spacing: 14) {
            Button {
                actions?.showGoToLine()
            } label: {
                Text(model.positionText).monospacedDigit()
            }
            .buttonStyle(.plain)
            .help(L10n.StatusBar.positionHelp)

            if let selectionText = model.selectionText {
                Button {
                    actions?.showStatistics()
                } label: {
                    Text(selectionText).monospacedDigit()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if attributes.isLargeFile {
                Label(L10n.StatusBar.largeFile, systemImage: "bolt.horizontal")
                    .foregroundStyle(.secondary)
            }

            if attributes.hasMixedLineEndings {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(L10n.StatusBar.mixedLineEndingsHelp)
                    .accessibilityLabel(L10n.StatusBar.mixedLineEndings)
            }

            languageMenu
            indentationMenu
            lineEndingMenu
            encodingMenu
        }
        .font(.system(size: 11))
        .padding(.horizontal, 12)
        .frame(height: 24)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.Accessibility.statusBar)
    }

    private var languageMenu: some View {
        Menu {
            Button(L10n.Menu.automaticLanguage) {
                actions?.selectLanguage(nil)
            }
            Divider()
            ForEach(LanguageCatalog.all) { language in
                Button(language.displayName) {
                    actions?.selectLanguage(language)
                }
            }
        } label: {
            Text(attributes.language.displayName)
        }
        .fixedSize()
        .help(L10n.StatusBar.languageHelp)
    }

    private var indentationMenu: some View {
        Menu {
            Button(L10n.Menu.indentWithSpaces) {
                actions?.setIndentation(Indentation(usesTabs: false, width: attributes.indentation.width))
            }
            Button(L10n.Menu.indentWithTabs) {
                actions?.setIndentation(Indentation(usesTabs: true, width: attributes.indentation.width))
            }
            Divider()
            Section(L10n.StatusBar.tabWidth) {
                ForEach([2, 3, 4, 8], id: \.self) { width in
                    Button(String(width)) {
                        actions?.setIndentation(Indentation(usesTabs: attributes.indentation.usesTabs, width: width))
                    }
                }
            }
            Divider()
            Button(L10n.Menu.detectIndentation) {
                actions?.detectIndentation()
            }
        } label: {
            Text(L10n.StatusBar.indentation(attributes.indentation))
        }
        .fixedSize()
        .help(L10n.StatusBar.indentationHelp)
    }

    private var lineEndingMenu: some View {
        Menu {
            ForEach(LineEnding.allCases, id: \.self) { lineEnding in
                Button(lineEnding.displayName) {
                    actions?.convert(to: lineEnding)
                }
            }
        } label: {
            Text(attributes.lineEnding.shortName)
        }
        .fixedSize()
        .help(attributes.hasMixedLineEndings ? L10n.StatusBar.mixedLineEndingsHelp : L10n.StatusBar.lineEndingHelp)
    }

    private var encodingMenu: some View {
        Menu {
            Menu(L10n.Menu.convertToEncoding) {
                encodingButtons { actions?.convert(to: $0) }
            }
            Menu(L10n.Menu.reopenWithEncoding) {
                encodingButtons { actions?.reopen(with: $0) }
            }
            .disabled(!canReopen)
        } label: {
            Text(attributes.encoding.shortName)
        }
        .fixedSize()
        .help(L10n.StatusBar.encodingHelp)
    }

    @ViewBuilder
    private func encodingButtons(_ action: @escaping (TextEncoding) -> Void) -> some View {
        ForEach(Array(TextEncoding.menuGroups.enumerated()), id: \.offset) { index, group in
            if index > 0 {
                Divider()
            }
            ForEach(group, id: \.self) { encoding in
                Button(encoding.displayName) {
                    action(encoding)
                }
            }
        }
    }
}
