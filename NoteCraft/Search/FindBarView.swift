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
            Task { @MainActor in
                focusedField = .search
            }
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
                Text(verbatim: "Aa").font(.system(.callout, design: .monospaced))
            }
            .help(L10n.Find.caseSensitive)
            .accessibilityLabel(L10n.Find.caseSensitive)

            Toggle(isOn: $model.matchesWholeWord) {
                Text(verbatim: "ab").font(.system(.callout, design: .monospaced)).underline()
            }
            .help(L10n.Find.wholeWord)
            .accessibilityLabel(L10n.Find.wholeWord)

            Toggle(isOn: $model.usesRegularExpression) {
                Text(verbatim: ".*").font(.system(.callout, design: .monospaced))
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
        (".", String(localized: "Any character except a line break")),
        (#"\d  \w  \s"#, String(localized: "Digit, word character, whitespace")),
        (#"\D  \W  \S"#, String(localized: "Anything but a digit, word character or whitespace")),
        (#"\b"#, String(localized: "Word boundary")),
        ("^  $", String(localized: "Start of line, end of line")),
        ("*  +  ?", String(localized: "0 or more, 1 or more, 0 or 1")),
        ("{2,5}", String(localized: "2 to 5 repetitions")),
        ("*?  +?", String(localized: "As few as possible")),
        ("[abc]  [^abc]", String(localized: "One of the characters, none of the characters")),
        ("[a-z0-9]", String(localized: "Character range")),
        ("a|b", String(localized: "a or b")),
        ("( … )", String(localized: "Group, used in the replacement as $1, $2 …")),
        ("(?: … )", String(localized: "Non-capturing group")),
        ("(?= … )  (?! … )", String(localized: "Followed by, not followed by")),
        (#"\n  \t"#, String(localized: "Line break, tab")),
        (#"\.  \(  \\"#, String(localized: "Match special characters literally")),
        ("$0", String(localized: "Whole match in the replacement"))
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
