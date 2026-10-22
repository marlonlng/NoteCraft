import Foundation
import NoteCraftKit
import Observation

@MainActor
@Observable
final class FileSearchModel {
    var folderURL: URL?
    var queryText = ""
    var isCaseSensitive = false
    var matchesWholeWord = false
    var usesRegularExpression = false
    var filePatternText = ""
    var includesHiddenFiles = false
    var focusRequest = 0
    private(set) var results: [FileSearchResult] = []
    private(set) var isSearching = false
    private(set) var hasSearched = false
    private(set) var validationMessage: String?

    @ObservationIgnored private var task: Task<Void, Never>?

    var query: SearchQuery {
        SearchQuery(
            text: queryText,
            isCaseSensitive: isCaseSensitive,
            matchesWholeWord: matchesWholeWord,
            usesRegularExpression: usesRegularExpression
        )
    }

    var totalMatches: Int {
        results.reduce(0) { $0 + $1.matches.count }
    }

    var summary: String? {
        guard hasSearched else { return nil }
        if isSearching, results.isEmpty {
            return L10n.FileSearch.searching
        }
        return L10n.FileSearch.summary(matches: totalMatches, files: results.count)
    }

    /// Starts a background search in the folder, replacing previous results.
    func search() {
        cancel()
        validationMessage = nil
        guard let folderURL, !queryText.isEmpty else { return }
        let request = FileSearchRequest(
            folderURL: folderURL,
            query: query,
            filePattern: FilePattern(filePatternText),
            includesHiddenFiles: includesHiddenFiles
        )
        let stream: AsyncStream<FileSearchResult>
        do {
            stream = try FileSearcher.results(for: request)
        } catch {
            validationMessage = (error as? LocalizedError)?.errorDescription
            return
        }
        results = []
        hasSearched = true
        isSearching = true
        task = Task { [weak self] in
            for await result in stream {
                guard !Task.isCancelled else { break }
                self?.results.append(result)
            }
            if !Task.isCancelled {
                self?.isSearching = false
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        isSearching = false
    }

    func clear() {
        cancel()
        results = []
        hasSearched = false
        validationMessage = nil
    }

    /// Waits for the running search to finish.
    func waitUntilFinished() async {
        await task?.value
    }

    /// Opens the file of `result` and selects `match`.
    func open(_ result: FileSearchResult, match: FileSearchMatch) {
        DocumentOpener.open(result.fileURL, selecting: match.range)
    }
}
