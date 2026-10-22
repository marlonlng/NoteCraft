import SwiftUI

struct FindBarView: View {
    @Bindable var model: FindBarModel
    @FocusState private var focusedField: Field?
    @State private var isShowingCheatSheet = false

    enum Field: Hashable {
        case search
        case replace
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    model.isReplaceVisible.toggle()
                } label: {
                    Image(systemName: model.isReplaceVisible ? "chevron.down" : "chevron.right")
                        .frame(width: 14)
                }
                .buttonStyle(.borderless)
                .help(L10n.Find.toggleReplace)
                .accessibilityLabel(L10n.Find.toggleReplace)

                TextField(L10n.Find.searchPlaceholder, text: $model.searchText)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .search)
                    .onSubmit { model.findNext() }
                    .onKeyPress(.return, phases: .down) { press in
                        guard press.modifiers.contains(.shift) else { return .ignored }
                        model.findPrevious()
                        return .handled
                    }
                    .frame(minWidth: 160)

                Text(model.matchStatus)
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 72, alignment: .trailing)
                    .accessibilityAddTraits(.updatesFrequently)

                optionToggles

                ControlGroup {
                    Button(action: model.findPrevious) {
                        Image(systemName: "chevron.left")
                    }
                    .help(L10n.Find.previous)
                    .accessibilityLabel(L10n.Find.previous)
                    Button(action: model.findNext) {
                        Image(systemName: "chevron.right")
                    }
                    .help(L10n.Find.next)
                    .accessibilityLabel(L10n.Find.next)
                }
                .fixedSize()
                .disabled(model.matches.isEmpty)

                Button {
                    isShowingCheatSheet.toggle()
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.borderless)
                .help(L10n.Menu.regexCheatSheet)
                .accessibilityLabel(L10n.Menu.regexCheatSheet)
                .popover(isPresented: $isShowingCheatSheet, arrowEdge: .bottom) {
                    RegexCheatSheetView()
                }

                Button(L10n.Find.done) {
                    model.hide()
                }
            }

            if model.isReplaceVisible {
                HStack(spacing: 8) {
                    Color.clear.frame(width: 14, height: 1)
                    TextField(L10n.Find.replacePlaceholder, text: $model.replacementText)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .replace)
                        .onSubmit { model.replace() }
                        .frame(minWidth: 160)
                    Button(L10n.Find.replace, action: model.replace)
                        .disabled(model.matches.isEmpty)
                    Button(L10n.Find.replaceAll, action: model.replaceAll)
                        .disabled(model.matches.isEmpty)
                    Spacer(minLength: 0)
                }
            }

            if let validationMessage = model.validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(.leading, 22)
            } else if let statusMessage = model.statusMessage {
                Text(statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 22)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .onChange(of: model.focusRequest, initial: true) {
            focusedField = .search
        }
        .onExitCommand {
            model.hide()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.Accessibility.findBar)
    }

    private var optionToggles: some View {
        HStack(spacing: 2) {
            Toggle(isOn: $model.isCaseSensitive) {
                Text("Aa").font(.system(.callout, design: .monospaced))
            }
            .help(L10n.Find.caseSensitive)
            .accessibilityLabel(L10n.Find.caseSensitive)

            Toggle(isOn: $model.matchesWholeWord) {
                Text("ab").font(.system(.callout, design: .monospaced)).underline()
            }
            .help(L10n.Find.wholeWord)
            .accessibilityLabel(L10n.Find.wholeWord)

            Toggle(isOn: $model.usesRegularExpression) {
                Text(".*").font(.system(.callout, design: .monospaced))
            }
            .help(L10n.Find.regularExpression)
            .accessibilityLabel(L10n.Find.regularExpression)

            Toggle(isOn: $model.searchesInSelection) {
                Image(systemName: "selection.pin.in.out")
            }
            .help(L10n.Find.inSelection)
            .accessibilityLabel(L10n.Find.inSelection)
        }
        .toggleStyle(.button)
        .buttonStyle(.borderless)
    }
}

struct RegexCheatSheetView: View {
    static let entries: [(pattern: String, meaning: String)] = [
        (".", String(localized: "Ein beliebiges Zeichen außer Zeilenende")),
        (#"\d  \w  \s"#, String(localized: "Ziffer, Wortzeichen, Leerraum")),
        (#"\D  \W  \S"#, String(localized: "Alles außer Ziffer, Wortzeichen, Leerraum")),
        (#"\b"#, String(localized: "Wortgrenze")),
        ("^  $", String(localized: "Zeilenanfang, Zeilenende")),
        ("*  +  ?", String(localized: "0 oder mehr, 1 oder mehr, 0 oder 1")),
        ("{2,5}", String(localized: "2 bis 5 Wiederholungen")),
        ("*?  +?", String(localized: "So wenig wie möglich")),
        ("[abc]  [^abc]", String(localized: "Eines der Zeichen, keines der Zeichen")),
        ("[a-z0-9]", String(localized: "Zeichenbereich")),
        ("a|b", String(localized: "a oder b")),
        ("( … )", String(localized: "Gruppe, in der Ersetzung als $1, $2 …")),
        ("(?: … )", String(localized: "Gruppe ohne Rückverweis")),
        ("(?= … )  (?! … )", String(localized: "Gefolgt von, nicht gefolgt von")),
        (#"\n  \t"#, String(localized: "Zeilenende, Tabulator")),
        (#"\.  \(  \\"#, String(localized: "Sonderzeichen wörtlich suchen")),
        ("$0", String(localized: "Gesamter Treffer in der Ersetzung"))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.Help.regexTitle)
                .font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                ForEach(Self.entries, id: \.pattern) { entry in
                    GridRow {
                        Text(entry.pattern)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                        Text(entry.meaning)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 440)
    }
}
