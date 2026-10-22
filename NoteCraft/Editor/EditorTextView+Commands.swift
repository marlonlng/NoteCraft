import AppKit
import NoteCraftKit

extension EditorTextView {
    @objc func shiftRight(_ sender: Any?) {
        apply(LineOperations.indent(in: nsString, selection: selectedRange(), unit: indentation.unit), actionName: L10n.Undo.indentation)
    }

    @objc func shiftLeft(_ sender: Any?) {
        apply(LineOperations.outdent(in: nsString, selection: selectedRange(), tabWidth: indentation.width), actionName: L10n.Undo.indentation)
    }

    @objc func toggleComment(_ sender: Any?) {
        apply(LineOperations.toggleComment(in: nsString, selection: selectedRange(), syntax: commentSyntax), actionName: L10n.Undo.comment)
    }

    @objc func duplicateLine(_ sender: Any?) {
        apply(LineOperations.duplicateLines(in: nsString, selection: selectedRange()), actionName: L10n.Undo.lineOperation)
    }

    @objc func moveLineUp(_ sender: Any?) {
        apply(LineOperations.moveLines(in: nsString, selection: selectedRange(), direction: .up), actionName: L10n.Undo.lineOperation)
    }

    @objc func moveLineDown(_ sender: Any?) {
        apply(LineOperations.moveLines(in: nsString, selection: selectedRange(), direction: .down), actionName: L10n.Undo.lineOperation)
    }

    @objc func deleteLine(_ sender: Any?) {
        apply(LineOperations.deleteLines(in: nsString, selection: selectedRange()), actionName: L10n.Undo.lineOperation)
    }

    @objc func selectNextOccurrence(_ sender: Any?) {
        let ranges = OccurrenceSelection.addingNextOccurrence(to: selectedRanges.map(\.rangeValue), in: nsString)
        setSelectedRanges(ranges.map { NSValue(range: $0) }, affinity: .downstream, stillSelecting: false)
        if let last = ranges.last {
            scrollRangeToVisible(last)
        }
    }

    @objc func selectAllOccurrences(_ sender: Any?) {
        let ranges = OccurrenceSelection.allOccurrences(of: selectedRange(), in: nsString)
        setSelectedRanges(ranges.map { NSValue(range: $0) }, affinity: .downstream, stillSelecting: false)
    }

    @objc func performTextTransformation(_ sender: Any?) {
        guard let rawValue = (sender as? NSMenuItem)?.representedObject as? String,
              let transformation = TextTransformation(rawValue: rawValue) else { return }
        transform(with: transformation)
    }

    /// Applies `transformation` to the selection or the whole document and reports failures in an alert.
    func transform(with transformation: TextTransformation) {
        do {
            let edit = try LineOperations.transform(
                transformation,
                in: nsString,
                selection: selectedRange(),
                indentation: indentation.unit
            )
            applyEdit(range: edit.range, replacement: edit.replacement, selectedRange: edit.selectedRange, actionName: L10n.Undo.transformation)
        } catch {
            presentTransformationError(error)
        }
    }

    @objc func convertTabsToSpaces(_ sender: Any?) {
        rewriteSelectionOrDocument { Indentation.expandTabs(in: $0, width: self.indentation.width) }
    }

    @objc func convertSpacesToTabs(_ sender: Any?) {
        rewriteSelectionOrDocument { Indentation.collapseLeadingSpaces(in: $0, width: self.indentation.width) }
    }

    private func rewriteSelectionOrDocument(_ transform: (String) -> String) {
        let selection = selectedRange()
        let range = selection.length == 0
            ? NSRange(location: 0, length: nsString.length)
            : LineOperations.contentLineRange(for: selection, in: nsString)
        let original = nsString.substring(with: range)
        let rewritten = transform(original)
        guard rewritten != original else { return }
        let selected = NSRange(location: range.location, length: (rewritten as NSString).length)
        applyEdit(range: range, replacement: rewritten, selectedRange: selection.length == 0 ? nil : selected, actionName: L10n.Undo.transformation)
    }

    private func presentTransformationError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = L10n.Alert.transformationFailed
        alert.informativeText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        alert.alertStyle = .warning
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(shiftRight(_:)), #selector(shiftLeft(_:)), #selector(duplicateLine(_:)), #selector(moveLineUp(_:)),
             #selector(moveLineDown(_:)), #selector(deleteLine(_:)), #selector(performTextTransformation(_:)),
             #selector(convertTabsToSpaces(_:)), #selector(convertSpacesToTabs(_:)):
            return isEditable
        case #selector(toggleComment(_:)):
            return isEditable && (commentSyntax.lineComment != nil || commentSyntax.blockComment != nil)
        default:
            return super.validateMenuItem(menuItem)
        }
    }
}
