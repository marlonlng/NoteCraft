import AppKit
import NoteCraftKit

@MainActor
struct MainMenuBuilder {
    static let shareItemIdentifier = NSUserInterfaceItemIdentifier("NoteCraftShareMenuItem")

    weak var appDelegate: AppDelegate?

    /// Builds the complete menu bar and registers the Window, Help and Services menus with the app.
    func build(for application: NSApplication = .shared) -> NSMenu {
        let mainMenu = NSMenu()
        let servicesMenu = NSMenu(title: L10n.App.services)
        let windowMenu = makeWindowMenu()
        let helpMenu = makeHelpMenu()
        mainMenu.addItem(submenuItem(L10n.App.name, makeAppMenu(servicesMenu: servicesMenu)))
        mainMenu.addItem(submenuItem(L10n.Menu.file, makeFileMenu()))
        mainMenu.addItem(submenuItem(L10n.Menu.edit, makeEditMenu()))
        mainMenu.addItem(submenuItem(L10n.Menu.text, makeTextMenu()))
        mainMenu.addItem(submenuItem(L10n.Menu.view, makeViewMenu()))
        mainMenu.addItem(submenuItem(L10n.Menu.window, windowMenu))
        mainMenu.addItem(submenuItem(L10n.Menu.help, helpMenu))
        application.servicesMenu = servicesMenu
        application.windowsMenu = windowMenu
        application.helpMenu = helpMenu
        return mainMenu
    }

    private func makeAppMenu(servicesMenu: NSMenu) -> NSMenu {
        let menu = NSMenu(title: L10n.App.name)
        menu.addItem(item(L10n.App.about, #selector(AppDelegate.showAboutPanel(_:)), target: appDelegate))
        menu.addItem(.separator())
        menu.addItem(item(L10n.App.settings, #selector(AppDelegate.showSettings(_:)), key: ",", target: appDelegate))
        menu.addItem(.separator())
        menu.addItem(submenuItem(L10n.App.services, servicesMenu))
        menu.addItem(.separator())
        menu.addItem(item(L10n.App.hide, #selector(NSApplication.hide(_:)), key: "h"))
        menu.addItem(item(L10n.App.hideOthers, #selector(NSApplication.hideOtherApplications(_:)), key: "h", modifiers: [.command, .option]))
        menu.addItem(item(L10n.App.showAll, #selector(NSApplication.unhideAllApplications(_:))))
        menu.addItem(.separator())
        menu.addItem(item(L10n.App.quit, #selector(NSApplication.terminate(_:)), key: "q"))
        return menu
    }

    private func makeFileMenu() -> NSMenu {
        let menu = NSMenu(title: L10n.Menu.file)
        menu.delegate = appDelegate
        menu.addItem(item(L10n.Menu.new, #selector(NSDocumentController.newDocument(_:)), key: "n"))
        menu.addItem(item(L10n.Menu.newTab, #selector(NSResponder.newWindowForTab(_:)), key: "t"))
        menu.addItem(item(L10n.Menu.open, #selector(NSDocumentController.openDocument(_:)), key: "o"))
        let recentMenu = NSMenu(title: L10n.Menu.openRecent)
        recentMenu.addItem(item(L10n.Menu.clearRecent, #selector(NSDocumentController.clearRecentDocuments(_:))))
        menu.addItem(submenuItem(L10n.Menu.openRecent, recentMenu))
        menu.addItem(.separator())
        menu.addItem(item(L10n.Menu.openFolder, #selector(AppDelegate.openFolder(_:)), key: "o", modifiers: [.command, .option]))
        menu.addItem(item(L10n.Menu.openQuickly, #selector(EditorWindowController.openQuickly(_:)), key: "o", modifiers: [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(item(L10n.Menu.close, #selector(NSWindow.performClose(_:)), key: "w"))
        menu.addItem(item(L10n.Menu.save, #selector(NSDocument.save(_:)), key: "s"))
        menu.addItem(item(L10n.Menu.duplicate, #selector(NSDocument.duplicate(_:)), key: "s", modifiers: [.command, .shift]))
        let saveAs = item(L10n.Menu.saveAs, #selector(NSDocument.saveAs(_:)), key: "s", modifiers: [.command, .shift, .option])
        saveAs.isAlternate = true
        menu.addItem(saveAs)
        menu.addItem(item(L10n.Menu.rename, #selector(NSDocument.rename(_:))))
        menu.addItem(item(L10n.Menu.moveTo, #selector(NSDocument.move(_:))))
        menu.addItem(item(L10n.Menu.revertTo, #selector(NSDocument.revertToSaved(_:))))
        menu.addItem(.separator())
        menu.addItem(submenuItem(L10n.Menu.encoding, makeEncodingMenu()))
        menu.addItem(submenuItem(L10n.Menu.lineEnding, makeLineEndingMenu()))
        menu.addItem(.separator())
        let share = submenuItem(L10n.Menu.share, NSMenu(title: L10n.Menu.share))
        share.identifier = Self.shareItemIdentifier
        menu.addItem(share)
        menu.addItem(item(L10n.Menu.revealInFinder, #selector(TextDocument.revealInFinder(_:))))
        menu.addItem(item(L10n.Menu.copyPath, #selector(TextDocument.copyFilePath(_:)), key: "c", modifiers: [.command, .shift, .option]))
        menu.addItem(.separator())
        menu.addItem(item(L10n.Menu.pageSetup, #selector(NSDocument.runPageLayout(_:)), key: "p", modifiers: [.command, .shift]))
        menu.addItem(item(L10n.Menu.print, #selector(NSDocument.printDocument(_:)), key: "p"))
        return menu
    }

    private func makeEncodingMenu() -> NSMenu {
        let menu = NSMenu(title: L10n.Menu.encoding)
        menu.addItem(submenuItem(L10n.Menu.reopenWithEncoding, encodingList(#selector(TextDocument.reopenWithEncoding(_:)))))
        menu.addItem(submenuItem(L10n.Menu.convertToEncoding, encodingList(#selector(TextDocument.convertToEncoding(_:)))))
        return menu
    }

    private func encodingList(_ action: Selector) -> NSMenu {
        let menu = NSMenu()
        for (index, group) in TextEncoding.menuGroups.enumerated() {
            if index > 0 {
                menu.addItem(.separator())
            }
            for encoding in group {
                menu.addItem(item(encoding.displayName, action, representedObject: encoding.rawValue))
            }
        }
        return menu
    }

    private func makeLineEndingMenu() -> NSMenu {
        let menu = NSMenu(title: L10n.Menu.lineEnding)
        for lineEnding in LineEnding.allCases {
            menu.addItem(item(lineEnding.displayName, #selector(TextDocument.changeLineEnding(_:)), representedObject: lineEnding.rawValue))
        }
        return menu
    }

    private func makeEditMenu() -> NSMenu {
        let menu = NSMenu(title: L10n.Menu.edit)
        menu.addItem(item(L10n.Menu.undo, Selector(("undo:")), key: "z"))
        menu.addItem(item(L10n.Menu.redo, Selector(("redo:")), key: "z", modifiers: [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(item(L10n.Menu.cut, #selector(NSText.cut(_:)), key: "x"))
        menu.addItem(item(L10n.Menu.copy, #selector(NSText.copy(_:)), key: "c"))
        menu.addItem(item(L10n.Menu.paste, #selector(NSText.paste(_:)), key: "v"))
        menu.addItem(item(L10n.Menu.delete, #selector(NSText.delete(_:))))
        menu.addItem(item(L10n.Menu.selectAll, #selector(NSText.selectAll(_:)), key: "a"))
        menu.addItem(.separator())

        let findMenu = NSMenu(title: L10n.Menu.find)
        findMenu.addItem(item(L10n.Menu.findEllipsis, #selector(EditorViewController.showFindBar(_:)), key: "f"))
        findMenu.addItem(item(L10n.Menu.findAndReplace, #selector(EditorViewController.showFindAndReplaceBar(_:)), key: "f", modifiers: [.command, .option]))
        findMenu.addItem(item(L10n.Menu.findNext, #selector(EditorViewController.findNextMatch(_:)), key: "g"))
        findMenu.addItem(item(L10n.Menu.findPrevious, #selector(EditorViewController.findPreviousMatch(_:)), key: "g", modifiers: [.command, .shift]))
        findMenu.addItem(item(L10n.Menu.useSelectionForFind, #selector(EditorViewController.useSelectionForFind(_:)), key: "e"))
        findMenu.addItem(item(L10n.Menu.useSelectionForReplace, #selector(EditorViewController.useSelectionForReplace(_:)), key: "e", modifiers: [.command, .shift]))
        findMenu.addItem(item(L10n.Menu.jumpToSelection, #selector(NSTextView.centerSelectionInVisibleArea(_:)), key: "j"))
        findMenu.addItem(.separator())
        findMenu.addItem(item(L10n.Menu.fileSearch, #selector(EditorWindowController.showFileSearch(_:)), key: "f", modifiers: [.command, .shift]))
        menu.addItem(submenuItem(L10n.Menu.find, findMenu))

        let selectionMenu = NSMenu(title: L10n.Menu.selection)
        selectionMenu.addItem(item(L10n.Menu.selectLine, #selector(NSResponder.selectLine(_:))))
        selectionMenu.addItem(item(L10n.Menu.selectNextOccurrence, #selector(EditorTextView.selectNextOccurrence(_:)), key: "e", modifiers: [.command, .option]))
        selectionMenu.addItem(item(L10n.Menu.selectAllOccurrences, #selector(EditorTextView.selectAllOccurrences(_:)), key: "g", modifiers: [.command, .control]))
        menu.addItem(submenuItem(L10n.Menu.selection, selectionMenu))
        menu.addItem(item(L10n.Menu.goToLine, #selector(EditorViewController.goToLine(_:)), key: "l"))
        menu.addItem(.separator())

        let spellingMenu = NSMenu(title: L10n.Menu.spelling)
        spellingMenu.addItem(item(L10n.Menu.showSpelling, #selector(NSText.showGuessPanel(_:)), key: ":"))
        spellingMenu.addItem(item(L10n.Menu.checkSpelling, #selector(NSText.checkSpelling(_:)), key: ";"))
        spellingMenu.addItem(item(L10n.Menu.checkSpellingWhileTyping, #selector(NSTextView.toggleContinuousSpellChecking(_:))))
        menu.addItem(submenuItem(L10n.Menu.spelling, spellingMenu))
        return menu
    }

    private func makeTextMenu() -> NSMenu {
        let menu = NSMenu(title: L10n.Menu.text)
        menu.addItem(item(L10n.Menu.shiftRight, #selector(EditorTextView.shiftRight(_:)), key: "]"))
        menu.addItem(item(L10n.Menu.shiftLeft, #selector(EditorTextView.shiftLeft(_:)), key: "["))
        menu.addItem(item(L10n.Menu.toggleComment, #selector(EditorTextView.toggleComment(_:)), key: "/"))
        menu.addItem(.separator())
        menu.addItem(item(L10n.Menu.duplicateLine, #selector(EditorTextView.duplicateLine(_:)), key: "d"))
        menu.addItem(item(L10n.Menu.moveLineUp, #selector(EditorTextView.moveLineUp(_:)), key: "[", modifiers: [.command, .option]))
        menu.addItem(item(L10n.Menu.moveLineDown, #selector(EditorTextView.moveLineDown(_:)), key: "]", modifiers: [.command, .option]))
        menu.addItem(item(L10n.Menu.deleteLine, #selector(EditorTextView.deleteLine(_:)), key: "k", modifiers: [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(submenuItem(L10n.Menu.lines, transformationMenu(L10n.Menu.lines, groups: [
            [.sortLinesAscending, .sortLinesDescending, .sortLinesByLength, .reverseLines, .shuffleLines],
            [.removeDuplicateLines, .removeEmptyLines, .joinLines]
        ])))
        let whitespaceMenu = transformationMenu(L10n.Menu.whitespace, groups: [[.trimTrailingWhitespace, .trimLeadingWhitespace]])
        whitespaceMenu.addItem(.separator())
        whitespaceMenu.addItem(item(L10n.Menu.convertTabsToSpaces, #selector(EditorTextView.convertTabsToSpaces(_:))))
        whitespaceMenu.addItem(item(L10n.Menu.convertSpacesToTabs, #selector(EditorTextView.convertSpacesToTabs(_:))))
        menu.addItem(submenuItem(L10n.Menu.whitespace, whitespaceMenu))
        menu.addItem(submenuItem(L10n.Menu.letterCase, transformationMenu(L10n.Menu.letterCase, groups: [
            [.uppercase, .lowercase, .capitalize, .invertCase],
            [.camelCase, .snakeCase, .kebabCase]
        ])))
        menu.addItem(submenuItem(L10n.Menu.encodeDecode, transformationMenu(L10n.Menu.encodeDecode, groups: [
            [.base64Encode, .base64Decode],
            [.urlEncode, .urlDecode],
            [.htmlEscape, .htmlUnescape]
        ])))
        menu.addItem(submenuItem(L10n.Menu.json, transformationMenu(L10n.Menu.json, groups: [[.formatJSON, .minifyJSON]])))
        menu.addItem(.separator())
        menu.addItem(submenuItem(L10n.Menu.language, makeLanguageMenu()))
        menu.addItem(submenuItem(L10n.Menu.indentation, makeIndentationMenu()))
        menu.addItem(.separator())
        menu.addItem(item(L10n.Menu.statistics, #selector(EditorViewController.showDocumentStatistics(_:))))
        return menu
    }

    private func transformationMenu(_ title: String, groups: [[TextTransformation]]) -> NSMenu {
        let menu = NSMenu(title: title)
        for (index, group) in groups.enumerated() {
            if index > 0 {
                menu.addItem(.separator())
            }
            for transformation in group {
                menu.addItem(item(
                    L10n.Transformation.title(for: transformation),
                    #selector(EditorTextView.performTextTransformation(_:)),
                    representedObject: transformation.rawValue
                ))
            }
        }
        return menu
    }

    private func makeLanguageMenu() -> NSMenu {
        let menu = NSMenu(title: L10n.Menu.language)
        menu.addItem(item(L10n.Menu.automaticLanguage, #selector(TextDocument.changeLanguage(_:)), representedObject: ""))
        menu.addItem(.separator())
        for language in LanguageCatalog.all {
            menu.addItem(item(language.displayName, #selector(TextDocument.changeLanguage(_:)), representedObject: language.id))
        }
        return menu
    }

    private func makeIndentationMenu() -> NSMenu {
        let menu = NSMenu(title: L10n.Menu.indentation)
        menu.addItem(item(L10n.Menu.indentWithSpaces, #selector(TextDocument.changeIndentationStyle(_:)), tag: 0))
        menu.addItem(item(L10n.Menu.indentWithTabs, #selector(TextDocument.changeIndentationStyle(_:)), tag: 1))
        menu.addItem(.separator())
        for width in [2, 3, 4, 8] {
            menu.addItem(item(L10n.StatusBar.indentation(Indentation(usesTabs: false, width: width)), #selector(TextDocument.changeTabWidth(_:)), tag: width))
        }
        menu.addItem(.separator())
        menu.addItem(item(L10n.Menu.detectIndentation, #selector(TextDocument.detectIndentationFromText(_:))))
        return menu
    }

    private func makeViewMenu() -> NSMenu {
        let menu = NSMenu(title: L10n.Menu.view)
        menu.addItem(item(L10n.Menu.showSidebar, #selector(NSSplitViewController.toggleSidebar(_:)), key: "s", modifiers: [.command, .control]))
        menu.addItem(item(L10n.Menu.hideStatusBar, #selector(EditorViewController.toggleStatusBar(_:))))
        menu.addItem(item(L10n.Menu.showTabBar, #selector(NSWindow.toggleTabBar(_:))))
        menu.addItem(item(L10n.Menu.showAllTabs, #selector(NSWindow.toggleTabOverview(_:))))
        menu.addItem(item(L10n.Menu.showToolbar, #selector(NSWindow.toggleToolbarShown(_:)), key: "t", modifiers: [.command, .option]))
        menu.addItem(item(L10n.Menu.customizeToolbar, #selector(NSWindow.runToolbarCustomizationPalette(_:))))
        menu.addItem(.separator())
        menu.addItem(item(L10n.Menu.hideLineNumbers, #selector(EditorViewController.toggleLineNumbers(_:))))
        menu.addItem(item(L10n.Menu.showInvisibles, #selector(EditorViewController.toggleInvisibleCharacters(_:))))
        menu.addItem(item(L10n.Menu.wrapLines, #selector(EditorViewController.toggleLineWrapping(_:))))
        menu.addItem(item(L10n.Menu.highlightCurrentLine, #selector(EditorViewController.toggleCurrentLineHighlight(_:))))
        menu.addItem(.separator())
        menu.addItem(item(L10n.Menu.zoomIn, #selector(EditorViewController.zoomIn(_:)), key: "+"))
        menu.addItem(item(L10n.Menu.zoomOut, #selector(EditorViewController.zoomOut(_:)), key: "-"))
        menu.addItem(item(L10n.Menu.actualSize, #selector(EditorViewController.resetZoom(_:)), key: "0"))
        menu.addItem(.separator())
        menu.addItem(item(L10n.Menu.commandPalette, #selector(EditorWindowController.showCommandPalette(_:)), key: "a", modifiers: [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(item(L10n.Menu.enterFullScreen, #selector(NSWindow.toggleFullScreen(_:)), key: "f", modifiers: [.command, .control]))
        return menu
    }

    private func makeWindowMenu() -> NSMenu {
        let menu = NSMenu(title: L10n.Menu.window)
        menu.addItem(item(L10n.Menu.minimize, #selector(NSWindow.performMiniaturize(_:)), key: "m"))
        menu.addItem(item(L10n.Menu.zoom, #selector(NSWindow.performZoom(_:))))
        menu.addItem(.separator())
        menu.addItem(item(L10n.Menu.bringAllToFront, #selector(NSApplication.arrangeInFront(_:))))
        return menu
    }

    private func makeHelpMenu() -> NSMenu {
        let menu = NSMenu(title: L10n.Menu.help)
        menu.addItem(item(L10n.Menu.helpItem, #selector(AppDelegate.showHelp(_:)), key: "?", target: appDelegate))
        menu.addItem(item(L10n.Menu.keyboardShortcuts, #selector(AppDelegate.showHelp(_:)), target: appDelegate))
        return menu
    }

    private func item(
        _ title: String,
        _ action: Selector?,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = [.command],
        target: AnyObject? = nil,
        representedObject: Any? = nil,
        tag: Int = 0
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = key.isEmpty ? [] : modifiers
        item.target = target
        item.representedObject = representedObject
        item.tag = tag
        return item
    }

    private func submenuItem(_ title: String, _ submenu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        submenu.title = title
        item.submenu = submenu
        return item
    }
}
