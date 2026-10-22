import NoteCraftKit
import SwiftUI

@MainActor
@Observable
final class GoToLineModel {
    let lineCount: Int
    var input = ""

    init(lineCount: Int) {
        self.lineCount = lineCount
    }

    /// The parsed one-based line and column, or `nil` when the input is invalid.
    var target: (line: Int, column: Int)? {
        let parts = input
            .trimmingCharacters(in: .whitespaces)
            .split(whereSeparator: { $0 == ":" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard (1...2).contains(parts.count), let line = Int(parts[0]) else { return nil }
        let column = parts.count == 2 ? Int(parts[1]) : 1
        guard let column, column >= 1, line >= 1, line <= lineCount else { return nil }
        return (line, column)
    }

    /// The German validation message for the current input, or `nil` when it is empty or valid.
    var validationMessage: String? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, target == nil else { return nil }
        let parts = trimmed.split(whereSeparator: { $0 == ":" || $0 == "," })
        if let first = parts.first, let line = Int(first.trimmingCharacters(in: .whitespaces)),
           parts.count <= 2, line < 1 || line > lineCount {
            return L10n.GoToLine.outOfRange(lineCount: lineCount)
        }
        return L10n.GoToLine.invalidFormat
    }
}

struct GoToLineView: View {
    @Bindable var model: GoToLineModel
    let onGo: (Int, Int) -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.GoToLine.title)
                .font(.headline)
            TextField(L10n.GoToLine.placeholder, text: $model.input)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit(go)
            Group {
                if let message = model.validationMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                } else {
                    Text(L10n.GoToLine.hint(lineCount: model.lineCount))
                        .foregroundStyle(.secondary)
                }
            }
            .font(.callout)
            HStack {
                Spacer()
                Button(L10n.GoToLine.cancel, role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(L10n.GoToLine.go, action: go)
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.target == nil)
            }
        }
        .padding(20)
        .frame(width: 320)
        .onAppear { isFocused = true }
    }

    private func go() {
        guard let target = model.target else { return }
        onGo(target.line, target.column)
    }
}

struct StatisticsView: View {
    let document: TextStatistics
    let selection: TextStatistics?
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.Statistics.title)
                .font(.headline)
            Grid(alignment: .trailing, horizontalSpacing: 24, verticalSpacing: 6) {
                GridRow {
                    Text("")
                    Text(L10n.Statistics.document).fontWeight(.semibold)
                    if selection != nil {
                        Text(L10n.Statistics.selection).fontWeight(.semibold)
                    }
                }
                row(L10n.Statistics.characters, document.characters, selection?.characters)
                row(L10n.Statistics.words, document.words, selection?.words)
                row(L10n.Statistics.lines, document.lines, selection?.lines)
            }
            HStack {
                Spacer()
                Button(L10n.Statistics.done, action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 300)
    }

    private func row(_ title: String, _ documentValue: Int, _ selectionValue: Int?) -> some View {
        GridRow {
            Text(title).gridColumnAlignment(.leading)
            Text(documentValue.formatted()).monospacedDigit()
            if let selectionValue {
                Text(selectionValue.formatted()).monospacedDigit()
            }
        }
    }
}

struct ExternalChangeBanner: View {
    let change: ExternalChange
    let onReload: () -> Void
    let onKeep: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .foregroundStyle(change == .reloaded ? Color.secondary : Color.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                if let detail {
                    Text(detail).font(.callout).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            switch change {
            case .modified:
                Button(L10n.Banner.keepMine, action: onKeep)
                Button(L10n.Banner.reload, action: onReload)
            case .deleted, .reloaded:
                Button(L10n.Banner.dismiss, action: onDismiss)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }

    private var symbolName: String {
        switch change {
        case .modified: "exclamationmark.triangle.fill"
        case .deleted: "trash"
        case .reloaded: "arrow.clockwise"
        }
    }

    private var title: String {
        switch change {
        case .modified: L10n.Banner.modifiedExternally
        case .deleted: L10n.Banner.deleted
        case .reloaded: L10n.Banner.reloaded
        }
    }

    private var detail: String? {
        switch change {
        case .modified: L10n.Banner.modifiedExternallyDetail
        case .deleted: L10n.Banner.deletedDetail
        case .reloaded: nil
        }
    }
}
