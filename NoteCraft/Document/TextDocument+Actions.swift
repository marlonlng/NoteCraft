import AppKit
import NoteCraftKit

extension TextDocument {
    @objc func reopenWithEncoding(_ sender: Any?) {
        guard let rawValue = (sender as? NSMenuItem)?.representedObject as? String,
              let encoding = TextEncoding(rawValue: rawValue) else { return }
        guard isDocumentEdited else {
            performReopen(with: encoding)
            return
        }
        let alert = NSAlert()
        alert.messageText = L10n.Alert.reopenTitle
        alert.informativeText = L10n.Alert.reopenMessage
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.Alert.reopen)
        alert.addButton(withTitle: L10n.Alert.cancel)
        if let window = windowForSheet {
            alert.beginSheetModal(for: window) { [weak self] response in
                guard response == .alertFirstButtonReturn else { return }
                MainActor.assumeIsolated {
                    self?.performReopen(with: encoding)
                }
            }
        } else if alert.runModal() == .alertFirstButtonReturn {
            performReopen(with: encoding)
        }
    }

    private func performReopen(with encoding: TextEncoding) {
        do {
            try reopen(with: encoding)
        } catch {
            presentErrorAsSheet(error)
        }
    }

    @objc func convertToEncoding(_ sender: Any?) {
        guard let rawValue = (sender as? NSMenuItem)?.representedObject as? String,
              let encoding = TextEncoding(rawValue: rawValue) else { return }
        do {
            try convert(to: encoding)
        } catch {
            presentErrorAsSheet(error)
        }
    }

    @objc func changeLineEnding(_ sender: Any?) {
        guard let rawValue = (sender as? NSMenuItem)?.representedObject as? String,
              let lineEnding = LineEnding(rawValue: rawValue) else { return }
        convert(to: lineEnding)
    }

    @objc func changeLanguage(_ sender: Any?) {
        let identifier = (sender as? NSMenuItem)?.representedObject as? String ?? ""
        setLanguage(Language.language(withID: identifier))
    }

    @objc func changeIndentationStyle(_ sender: Any?) {
        guard let tag = (sender as? NSMenuItem)?.tag else { return }
        var indentation = attributes.indentation
        indentation.usesTabs = tag == 1
        setIndentation(indentation)
    }

    @objc func changeTabWidth(_ sender: Any?) {
        guard let width = (sender as? NSMenuItem)?.tag, width > 0 else { return }
        var indentation = attributes.indentation
        indentation.width = width
        setIndentation(indentation)
    }

    @objc func detectIndentationFromText(_ sender: Any?) {
        detectIndentation()
    }

    @objc func revealInFinder(_ sender: Any?) {
        guard let fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    @objc func copyFilePath(_ sender: Any?) {
        guard let fileURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fileURL.path, forType: .string)
    }

    func presentErrorAsSheet(_ error: Error) {
        if let window = windowForSheet {
            presentError(error, modalFor: window, delegate: nil, didPresent: nil, contextInfo: nil)
        } else {
            presentError(error)
        }
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(reopenWithEncoding(_:)):
            menuItem.state = (menuItem.representedObject as? String) == attributes.encoding.rawValue ? .on : .off
            return fileURL != nil
        case #selector(convertToEncoding(_:)):
            menuItem.state = (menuItem.representedObject as? String) == attributes.encoding.rawValue ? .on : .off
            return true
        case #selector(changeLineEnding(_:)):
            let isCurrent = (menuItem.representedObject as? String) == attributes.lineEnding.rawValue
            menuItem.state = isCurrent ? (attributes.hasMixedLineEndings ? .mixed : .on) : .off
            return true
        case #selector(changeLanguage(_:)):
            let identifier = menuItem.representedObject as? String ?? ""
            if identifier.isEmpty {
                menuItem.state = attributes.isLanguageOverridden ? .off : .on
            } else {
                menuItem.state = attributes.isLanguageOverridden && identifier == attributes.language.id ? .on : .off
            }
            return true
        case #selector(changeIndentationStyle(_:)):
            menuItem.state = (menuItem.tag == 1) == attributes.indentation.usesTabs ? .on : .off
            return true
        case #selector(changeTabWidth(_:)):
            menuItem.state = menuItem.tag == attributes.indentation.width ? .on : .off
            return true
        case #selector(revealInFinder(_:)), #selector(copyFilePath(_:)):
            return fileURL != nil
        default:
            return super.validateMenuItem(menuItem)
        }
    }
}
