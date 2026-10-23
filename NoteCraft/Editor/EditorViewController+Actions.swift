import AppKit
import NoteCraftKit
import SwiftUI

extension EditorViewController: NSMenuItemValidation {
    @objc func showFindBar(_ sender: Any?) {
        if textView.selectedRange().length > 0, !findBarModel.isVisible {
            findBarModel.useSelectionForFind()
        }
        findBarModel.show(replacing: false)
        focusFindBar()
    }

    @objc func showFindAndReplaceBar(_ sender: Any?) {
        findBarModel.show(replacing: true)
        focusFindBar()
    }

    private func focusFindBar() {
        findBarHost.layoutSubtreeIfNeeded()
        view.window?.makeFirstResponder(findBarHost)
    }

    @objc func findNextMatch(_ sender: Any?) {
        ensureSearchText()
        findBarModel.findNext()
    }

    @objc func findPreviousMatch(_ sender: Any?) {
        ensureSearchText()
        findBarModel.findPrevious()
    }

    @objc func useSelectionForFind(_ sender: Any?) {
        findBarModel.useSelectionForFind()
    }

    @objc func useSelectionForReplace(_ sender: Any?) {
        findBarModel.useSelectionForReplace()
        findBarModel.show(replacing: true)
        focusFindBar()
    }

    private func ensureSearchText() {
        if findBarModel.searchText.isEmpty, let shared = findBarModel.sharedSearchText {
            findBarModel.searchText = shared
        }
    }

    @objc func goToLine(_ sender: Any?) {
        showGoToLine()
    }

    @objc func showDocumentStatistics(_ sender: Any?) {
        showStatistics()
    }

    @objc func zoomIn(_ sender: Any?) {
        zoom(by: 1)
    }

    @objc func zoomOut(_ sender: Any?) {
        zoom(by: -1)
    }

    @objc func resetZoom(_ sender: Any?) {
        zoom(by: 0)
    }

    @objc func toggleLineNumbers(_ sender: Any?) {
        settingsStore.settings.showsLineNumbers.toggle()
    }

    @objc func toggleInvisibleCharacters(_ sender: Any?) {
        settingsStore.settings.showsInvisibleCharacters.toggle()
    }

    @objc func toggleLineWrapping(_ sender: Any?) {
        settingsStore.settings.wrapsLines.toggle()
    }

    @objc func toggleCurrentLineHighlight(_ sender: Any?) {
        settingsStore.settings.highlightsCurrentLine.toggle()
    }

    @objc func toggleStatusBar(_ sender: Any?) {
        showsStatusBar.toggle()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let settings = settings
        switch menuItem.action {
        case #selector(toggleLineNumbers(_:)):
            menuItem.title = settings.showsLineNumbers ? L10n.Menu.hideLineNumbers : L10n.Menu.showLineNumbers
        case #selector(toggleInvisibleCharacters(_:)):
            menuItem.title = settings.showsInvisibleCharacters ? L10n.Menu.hideInvisibles : L10n.Menu.showInvisibles
        case #selector(toggleStatusBar(_:)):
            menuItem.title = showsStatusBar ? L10n.Menu.hideStatusBar : L10n.Menu.showStatusBar
        case #selector(togglePreview(_:)):
            menuItem.title = isPreviewVisible ? L10n.Menu.hidePreview : L10n.Menu.showPreview
            return isMarkdownDocument
        case #selector(exportAsHTML(_:)), #selector(copyAsFormattedText(_:)):
            return isMarkdownDocument
        case #selector(toggleLineWrapping(_:)):
            menuItem.state = settings.wrapsLines ? .on : .off
        case #selector(toggleCurrentLineHighlight(_:)):
            menuItem.state = settings.highlightsCurrentLine ? .on : .off
        case #selector(findNextMatch(_:)), #selector(findPreviousMatch(_:)):
            return !findBarModel.searchText.isEmpty || findBarModel.sharedSearchText?.isEmpty == false
        case #selector(useSelectionForFind(_:)), #selector(useSelectionForReplace(_:)):
            return textView.selectedRange().length > 0
        case #selector(zoomIn(_:)):
            return zoomScale < (Self.zoomSteps.last ?? 3)
        case #selector(zoomOut(_:)):
            return zoomScale > (Self.zoomSteps.first ?? 0.5)
        case #selector(resetZoom(_:)):
            return zoomScale != 1
        default:
            break
        }
        return true
    }
}

extension EditorViewController: StatusBarActions {
    func showGoToLine() {
        let model = GoToLineModel(lineCount: lineIndex.lineCount)
        let hostingController = NSHostingController<GoToLineView>(rootView: GoToLineView(model: model, onGo: { _, _ in }, onCancel: {}))
        hostingController.rootView = GoToLineView(
            model: model,
            onGo: { [weak self, weak hostingController] line, column in
                guard let self, let hostingController else { return }
                self.dismiss(hostingController)
                self.goTo(line: line, column: column)
            },
            onCancel: { [weak self, weak hostingController] in
                guard let self, let hostingController else { return }
                self.dismiss(hostingController)
            }
        )
        presentAsSheet(hostingController)
    }

    func showStatistics() {
        let text = textView.string
        let selection = textView.selectedRange()
        let documentStatistics = TextStatistics.compute(for: text)
        let selectionStatistics = selection.length > 0 ? TextStatistics.compute(for: textView.nsString.substring(with: selection)) : nil
        let hostingController = NSHostingController<StatisticsView>(rootView: StatisticsView(document: documentStatistics, selection: selectionStatistics, onDone: {}))
        hostingController.rootView = StatisticsView(document: documentStatistics, selection: selectionStatistics) { [weak self, weak hostingController] in
            guard let self, let hostingController else { return }
            self.dismiss(hostingController)
        }
        presentAsSheet(hostingController)
    }

    func selectLanguage(_ language: Language?) {
        document.setLanguage(language)
    }

    func reopen(with encoding: TextEncoding) {
        let item = NSMenuItem()
        item.representedObject = encoding.rawValue
        document.reopenWithEncoding(item)
    }

    func convert(to encoding: TextEncoding) {
        do {
            try document.convert(to: encoding)
        } catch {
            document.presentErrorAsSheet(error)
        }
    }

    func convert(to lineEnding: LineEnding) {
        document.convert(to: lineEnding)
    }

    func setIndentation(_ indentation: Indentation) {
        document.setIndentation(indentation)
    }

    func detectIndentation() {
        document.detectIndentation()
    }
}
