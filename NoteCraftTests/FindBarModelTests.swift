import AppKit
import NoteCraftKit
import Testing
@testable import NoteCraft

@MainActor
struct FindBarModelTests {
    private func makeModel(_ text: String) -> (FindBarModel, FakeSearchTarget, FindPasteboard) {
        let pasteboard = FindPasteboard(pasteboard: TestSupport.makePasteboard())
        let model = FindBarModel(findPasteboard: pasteboard)
        let target = FakeSearchTarget(text)
        model.target = target
        return (model, target, pasteboard)
    }

    @Test func prefillsFromFindPasteboardAndCountsMatches() {
        let (model, target, pasteboard) = makeModel("one two one")
        pasteboard.string = "one"
        model.show(replacing: false)
        #expect(model.isVisible)
        #expect(!model.isReplaceVisible)
        #expect(model.searchText == "one")
        #expect(model.matches.count == 2)
        #expect(target.highlighted.count == 2)
        #expect(model.matchStatus == L10n.Find.matchStatus(current: nil, total: 2))
        #expect(model.focusRequest == 1)
    }

    @Test func ignoresMultilineFindPasteboardContent() {
        let (model, _, pasteboard) = makeModel("x")
        pasteboard.string = "a\nb"
        model.show(replacing: true)
        #expect(model.searchText.isEmpty)
        #expect(model.isReplaceVisible)
        #expect(model.matchStatus.isEmpty)
    }

    @Test func navigatesWithWrapAround() {
        let (model, target, pasteboard) = makeModel("ab ab ab")
        model.show(replacing: false)
        model.searchText = "ab"
        model.findNext()
        #expect(target.selection == NSRange(location: 0, length: 2))
        model.findNext()
        #expect(target.selection == NSRange(location: 3, length: 2))
        #expect(model.currentMatchIndex == 1)
        #expect(model.matchStatus == L10n.Find.matchStatus(current: 2, total: 3))
        model.findNext()
        model.findNext()
        #expect(target.selection == NSRange(location: 0, length: 2))
        model.findPrevious()
        #expect(target.selection == NSRange(location: 6, length: 2))
        #expect(pasteboard.string == "ab")
    }

    @Test func reportsMissingMatches() {
        let (model, target, _) = makeModel("abc")
        model.show(replacing: false)
        model.searchText = "zzz"
        #expect(model.matchStatus == L10n.Find.noMatches)
        model.findNext()
        #expect(target.selection == NSRange(location: 0, length: 0))
        model.searchText = ""
        model.findNext()
        #expect(model.matches.isEmpty)
    }

    @Test func validatesRegularExpressions() {
        let (model, target, _) = makeModel("abc")
        model.show(replacing: false)
        model.usesRegularExpression = true
        model.searchText = "(a"
        #expect(model.validationMessage == L10n.Find.invalidRegularExpression)
        #expect(model.matches.isEmpty)
        #expect(target.highlighted.isEmpty)
        #expect(model.matchStatus.isEmpty)
        model.searchText = "(a)"
        #expect(model.validationMessage == nil)
        #expect(model.matches.count == 1)
    }

    @Test func respectsOptions() {
        let (model, target, _) = makeModel("Word word words")
        defer { withExtendedLifetime(target) {} }
        model.show(replacing: false)
        model.searchText = "word"
        #expect(model.matches.count == 3)
        model.isCaseSensitive = true
        #expect(model.matches.count == 2)
        model.matchesWholeWord = true
        #expect(model.matches.count == 1)
    }

    @Test func replacesCurrentMatchAndMovesOn() {
        let (model, target, _) = makeModel("x1 x2 x3")
        model.show(replacing: true)
        model.usesRegularExpression = true
        model.searchText = #"x(\d)"#
        model.replacementText = "y$1"
        model.replace()
        #expect(target.selection == NSRange(location: 0, length: 2))
        model.replace()
        #expect(target.text as String == "y1 x2 x3")
        #expect(target.selection == NSRange(location: 3, length: 2))
    }

    @Test func replacesAllWithinSelectionScope() {
        let (model, target, _) = makeModel("a a a a")
        model.show(replacing: true)
        model.searchText = "a"
        target.selection = NSRange(location: 2, length: 3)
        model.searchesInSelection = true
        #expect(model.scope == NSRange(location: 2, length: 3))
        #expect(model.matches.count == 2)
        model.replacementText = "bb"
        model.replaceAll()
        #expect(target.text as String == "a bb bb a")
        #expect(target.lastActionName == L10n.Find.replaceAllActionName)
        #expect(model.statusMessage == L10n.Find.replacedStatus(2))
        #expect(model.scope == NSRange(location: 2, length: 5))
        model.searchesInSelection = false
        #expect(model.scope == nil)
    }

    @Test func refusesSelectionScopeWithoutSelection() {
        let (model, target, _) = makeModel("abc")
        defer { withExtendedLifetime(target) {} }
        model.show(replacing: false)
        model.searchesInSelection = true
        #expect(!model.searchesInSelection)
        #expect(model.scope == nil)
    }

    @Test func reportsWhenReplaceAllFindsNothing() {
        let (model, target, _) = makeModel("abc")
        model.show(replacing: true)
        model.searchText = "x"
        model.replaceAll()
        #expect(model.statusMessage == L10n.Find.noMatches)
        #expect(target.text as String == "abc")
    }

    @Test func usesSelectionForFindAndReplace() {
        let (model, target, pasteboard) = makeModel("hello world")
        model.useSelectionForFind()
        #expect(model.searchText.isEmpty)
        target.selection = NSRange(location: 6, length: 5)
        model.useSelectionForFind()
        #expect(model.searchText == "world")
        #expect(pasteboard.string == "world")
        model.useSelectionForReplace()
        #expect(model.replacementText == "world")
        #expect(model.isReplaceVisible)
        #expect(model.sharedSearchText == "world")
    }

    @Test func hidesAndRestoresFocus() {
        let (model, target, _) = makeModel("abc")
        model.show(replacing: false)
        model.searchText = "b"
        model.hide()
        #expect(!model.isVisible)
        #expect(target.focused)
        #expect(target.highlighted.isEmpty)
        model.refresh()
        #expect(model.matches.isEmpty)
    }

    @Test func tracksCurrentMatchFromSelection() {
        let (model, target, _) = makeModel("aa aa")
        model.show(replacing: false)
        model.searchText = "aa"
        target.selection = NSRange(location: 3, length: 2)
        model.updateCurrentMatch()
        #expect(model.currentMatchIndex == 1)
        model.target = nil
        model.updateCurrentMatch()
        #expect(model.currentMatchIndex == nil)
    }
}

@MainActor
struct GoToLineModelTests {
    @Test(arguments: [
        ("12", 12, 1),
        (" 7 : 3 ", 7, 3),
        ("5,2", 5, 2)
    ])
    func parsesValidInput(input: String, line: Int, column: Int) {
        let model = GoToLineModel(lineCount: 20)
        model.input = input
        #expect(model.target?.line == line)
        #expect(model.target?.column == column)
        #expect(model.validationMessage == nil)
    }

    @Test func explainsInvalidInput() {
        let model = GoToLineModel(lineCount: 20)
        #expect(model.validationMessage == nil)
        model.input = "abc"
        #expect(model.validationMessage == L10n.GoToLine.invalidFormat)
        model.input = "21"
        #expect(model.validationMessage == L10n.GoToLine.outOfRange(lineCount: 20))
        model.input = "0"
        #expect(model.validationMessage == L10n.GoToLine.outOfRange(lineCount: 20))
        model.input = "3:0"
        #expect(model.validationMessage == L10n.GoToLine.invalidFormat)
        model.input = "1:2:3"
        #expect(model.target == nil)
    }
}

@MainActor
struct StatusBarModelTests {
    @Test func describesPositionAndSelection() {
        let model = StatusBarModel()
        model.position = TextPosition(line: 4, column: 9)
        #expect(model.positionText == "Line 4, Column 9")
        #expect(model.selectionText == nil)
        model.selectedLength = 1
        #expect(model.selectionText == "1 character selected")
        model.selectedLength = 12
        #expect(model.selectionText == "12 characters selected")
        model.selectionCount = 3
        #expect(model.selectionText == "3 selections")
    }
}
