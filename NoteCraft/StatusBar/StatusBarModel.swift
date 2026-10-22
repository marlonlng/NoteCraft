import Foundation
import NoteCraftKit
import Observation

@MainActor
@Observable
final class StatusBarModel {
    var position = TextPosition(line: 1, column: 1)
    var selectedLength = 0
    var selectionCount = 1
    var lineCount = 1

    /// The caret position, e.g. `Zeile 12, Spalte 4`.
    var positionText: String {
        L10n.StatusBar.position(line: position.line, column: position.column)
    }

    /// The selection summary, or `nil` when nothing is selected.
    var selectionText: String? {
        guard selectionCount > 1 || selectedLength > 0 else { return nil }
        return L10n.StatusBar.selection(characters: selectedLength, ranges: selectionCount)
    }
}

@MainActor
protocol StatusBarActions: AnyObject {
    func showGoToLine()
    func showStatistics()
    func selectLanguage(_ language: Language?)
    func reopen(with encoding: TextEncoding)
    func convert(to encoding: TextEncoding)
    func convert(to lineEnding: LineEnding)
    func setIndentation(_ indentation: Indentation)
    func detectIndentation()
}
