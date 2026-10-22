import AppKit
import NoteCraftKit
import Observation

@MainActor
protocol SearchTarget: AnyObject {
    var searchableText: NSString { get }
    var searchSelection: NSRange { get }
    func showMatch(_ range: NSRange)
    func replaceMatch(_ range: NSRange, with replacement: String) -> Bool
    func replaceText(in range: NSRange, with replacement: String, actionName: String)
    func highlightMatches(_ ranges: [NSRange])
    func focusEditor()
}

@MainActor
@Observable
final class FindBarModel {
    static let matchLimit = 100_000
    static let highlightLimit = 5_000

    var isVisible = false
    var isReplaceVisible = false
    var focusRequest = 0

    var searchText = "" {
        didSet {
            if searchText != oldValue {
                refresh()
            }
        }
    }

    var replacementText = ""

    var isCaseSensitive = false {
        didSet { refresh() }
    }

    var matchesWholeWord = false {
        didSet { refresh() }
    }

    var usesRegularExpression = false {
        didSet { refresh() }
    }

    var searchesInSelection = false {
        didSet {
            if searchesInSelection, let selection = target?.searchSelection, selection.length > 0 {
                scope = selection
            } else if searchesInSelection {
                searchesInSelection = false
            } else {
                scope = nil
            }
            refresh()
        }
    }

    private(set) var scope: NSRange?
    private(set) var matches: [NSRange] = []
    private(set) var currentMatchIndex: Int?
    private(set) var validationMessage: String?
    private(set) var statusMessage: String?

    @ObservationIgnored weak var target: SearchTarget?
    @ObservationIgnored private let findPasteboard: FindPasteboard

    init(findPasteboard: FindPasteboard = FindPasteboard()) {
        self.findPasteboard = findPasteboard
    }

    var query: SearchQuery {
        SearchQuery(
            text: searchText,
            isCaseSensitive: isCaseSensitive,
            matchesWholeWord: matchesWholeWord,
            usesRegularExpression: usesRegularExpression
        )
    }

    /// The text shown next to the search field, e.g. `3 von 12`.
    var matchStatus: String {
        guard !searchText.isEmpty, validationMessage == nil else { return "" }
        guard !matches.isEmpty else { return L10n.Find.noMatches }
        return L10n.Find.matchStatus(current: currentMatchIndex.map { $0 + 1 }, total: matches.count)
    }

    private var effectiveScope: NSRange? {
        guard let scope, let target else { return nil }
        let length = target.searchableText.length
        let location = min(scope.location, length)
        return NSRange(location: location, length: min(scope.length, length - location))
    }

    /// Shows the find bar, prefilled from the system find pasteboard when empty, and focuses the search field.
    func show(replacing: Bool) {
        isVisible = true
        if replacing {
            isReplaceVisible = true
        }
        if searchText.isEmpty, let shared = findPasteboard.string, !shared.contains("\n") {
            searchText = shared
        }
        focusRequest += 1
        refresh()
    }

    /// Hides the find bar, removes match highlights and returns focus to the editor.
    func hide() {
        isVisible = false
        statusMessage = nil
        target?.highlightMatches([])
        target?.focusEditor()
    }

    /// Recomputes all matches for the current query and highlights them.
    func refresh() {
        statusMessage = nil
        guard let target else { return }
        guard isVisible, !searchText.isEmpty else {
            matches = []
            currentMatchIndex = nil
            validationMessage = nil
            target.highlightMatches([])
            return
        }
        do {
            let searcher = try TextSearcher(query: query)
            validationMessage = nil
            matches = searcher.matches(in: target.searchableText, range: effectiveScope, limit: Self.matchLimit)
            updateCurrentMatch()
            target.highlightMatches(Array(matches.prefix(Self.highlightLimit)))
        } catch {
            validationMessage = (error as? LocalizedError)?.errorDescription
            matches = []
            currentMatchIndex = nil
            target.highlightMatches([])
        }
    }

    /// Marks the match that equals the current selection as the current match.
    func updateCurrentMatch() {
        guard let selection = target?.searchSelection else {
            currentMatchIndex = nil
            return
        }
        currentMatchIndex = matchIndex(of: selection)
    }

    func findNext() {
        navigate(.forward)
    }

    func findPrevious() {
        navigate(.backward)
    }

    private func navigate(_ direction: SearchDirection) {
        guard let target, !searchText.isEmpty, let searcher = try? TextSearcher(query: query) else {
            NSSound.beep()
            return
        }
        findPasteboard.string = searchText
        let selection = target.searchSelection
        let start = direction == .forward ? NSMaxRange(selection) : selection.location
        guard let match = searcher.nextMatch(
            in: target.searchableText,
            from: start,
            direction: direction,
            wrapsAround: true,
            within: effectiveScope
        ) else {
            currentMatchIndex = nil
            NSSound.beep()
            return
        }
        target.showMatch(match)
        currentMatchIndex = matchIndex(of: match)
    }

    /// Replaces the selected match and moves on to the next one.
    func replace() {
        guard let target, let searcher = try? TextSearcher(query: query) else { return }
        let selection = target.searchSelection
        if matchIndex(of: selection) != nil {
            let replacement = searcher.replacementText(for: selection, in: target.searchableText, template: replacementText)
            _ = target.replaceMatch(selection, with: replacement)
            refresh()
        }
        findNext()
    }

    /// Replaces every match in the document or the selection scope as one undoable step.
    func replaceAll() {
        guard let target, let searcher = try? TextSearcher(query: query) else { return }
        let fullText = target.searchableText
        let range = effectiveScope ?? NSRange(location: 0, length: fullText.length)
        let original = fullText.substring(with: range)
        let result = searcher.replaceAll(in: original, with: replacementText)
        guard result.replacementCount > 0 else {
            statusMessage = L10n.Find.noMatches
            NSSound.beep()
            return
        }
        target.replaceText(in: range, with: result.text, actionName: L10n.Find.replaceAllActionName)
        if scope != nil {
            scope = NSRange(location: range.location, length: (result.text as NSString).length)
        }
        refresh()
        statusMessage = L10n.Find.replacedStatus(result.replacementCount)
    }

    /// Copies the selected text into the search field and the system find pasteboard.
    func useSelectionForFind() {
        guard let target else { return }
        let selection = target.searchSelection
        guard selection.length > 0 else {
            NSSound.beep()
            return
        }
        searchText = target.searchableText.substring(with: selection)
        findPasteboard.string = searchText
    }

    /// Copies the selected text into the replacement field.
    func useSelectionForReplace() {
        guard let target else { return }
        let selection = target.searchSelection
        guard selection.length > 0 else { return }
        replacementText = target.searchableText.substring(with: selection)
        isReplaceVisible = true
    }

    private func matchIndex(of range: NSRange) -> Int? {
        var low = 0
        var high = matches.count - 1
        while low <= high {
            let mid = (low + high) / 2
            let candidate = matches[mid]
            if candidate == range {
                return mid
            }
            if candidate.location < range.location || (candidate.location == range.location && candidate.length < range.length) {
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return nil
    }
}
