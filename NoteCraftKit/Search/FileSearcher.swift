import Foundation

public struct FilePattern: Equatable, Sendable {
    public let includes: [String]
    public let excludes: [String]

    /// Parses a comma separated list such as `*.swift, *.md, !Tests/*`; entries starting with `!` exclude files.
    public init(_ text: String) {
        let entries = text
            .split(whereSeparator: { $0 == "," || $0 == ";" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        includes = entries.filter { !$0.hasPrefix("!") }
        excludes = entries.filter { $0.hasPrefix("!") }.map { String($0.dropFirst()) }
    }

    /// Whether a file with the given path relative to the search folder passes the pattern.
    public func matches(relativePath: String) -> Bool {
        let fileName = (relativePath as NSString).lastPathComponent
        let isExcluded = excludes.contains { Self.glob($0, matches: fileName) || Self.glob($0, matches: relativePath) }
        guard !isExcluded else { return false }
        guard !includes.isEmpty else { return true }
        return includes.contains { Self.glob($0, matches: fileName) || Self.glob($0, matches: relativePath) }
    }

    /// Matches `name` against a glob supporting `*`, `?` and `**` (case-insensitive).
    public static func glob(_ pattern: String, matches name: String) -> Bool {
        let pattern = Array(pattern.lowercased())
        let name = Array(name.lowercased())
        var memo: [Int: Bool] = [:]

        func match(_ patternIndex: Int, _ nameIndex: Int) -> Bool {
            let key = patternIndex * (name.count + 1) + nameIndex
            if let cached = memo[key] {
                return cached
            }
            let result: Bool
            if patternIndex == pattern.count {
                result = nameIndex == name.count
            } else if pattern[patternIndex] == "*" {
                let isDoubleStar = patternIndex + 1 < pattern.count && pattern[patternIndex + 1] == "*"
                let next = isDoubleStar ? patternIndex + 2 : patternIndex + 1
                var cursor = nameIndex
                var found = match(next, cursor)
                while !found, cursor < name.count, isDoubleStar || name[cursor] != "/" {
                    cursor += 1
                    found = match(next, cursor)
                }
                result = found
            } else if nameIndex < name.count, pattern[patternIndex] == "?" || pattern[patternIndex] == name[nameIndex] {
                result = match(patternIndex + 1, nameIndex + 1)
            } else {
                result = false
            }
            memo[key] = result
            return result
        }

        return match(0, 0)
    }
}

public struct FileSearchMatch: Equatable, Sendable {
    public let range: NSRange
    public let lineNumber: Int
    public let lineText: String
    public let rangeInLine: NSRange

    public init(range: NSRange, lineNumber: Int, lineText: String, rangeInLine: NSRange) {
        self.range = range
        self.lineNumber = lineNumber
        self.lineText = lineText
        self.rangeInLine = rangeInLine
    }
}

public struct FileSearchResult: Equatable, Sendable, Identifiable {
    public let fileURL: URL
    public let relativePath: String
    public let matches: [FileSearchMatch]

    public var id: URL { fileURL }

    public init(fileURL: URL, relativePath: String, matches: [FileSearchMatch]) {
        self.fileURL = fileURL
        self.relativePath = relativePath
        self.matches = matches
    }
}

public struct FileSearchRequest: Sendable {
    public let folderURL: URL
    public let query: SearchQuery
    public let filePattern: FilePattern
    public let includesHiddenFiles: Bool
    public let maximumFileSize: Int
    public let maximumMatchesPerFile: Int

    public init(
        folderURL: URL,
        query: SearchQuery,
        filePattern: FilePattern = FilePattern(""),
        includesHiddenFiles: Bool = false,
        maximumFileSize: Int = 20_000_000,
        maximumMatchesPerFile: Int = 1_000
    ) {
        self.folderURL = folderURL
        self.query = query
        self.filePattern = filePattern
        self.includesHiddenFiles = includesHiddenFiles
        self.maximumFileSize = maximumFileSize
        self.maximumMatchesPerFile = maximumMatchesPerFile
    }
}

public enum FileSearcher {
    public static let skippedFolderNames: Set<String> = [
        ".git", ".svn", ".hg", "node_modules", ".build", "DerivedData", "Pods", ".swiftpm", "__pycache__", ".venv"
    ]

    /// Lists the files of the request's folder that pass the file pattern, sorted by relative path.
    public static func candidateFiles(for request: FileSearchRequest) -> [(url: URL, relativePath: String)] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .fileSizeKey, .isHiddenKey]
        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if !request.includesHiddenFiles {
            options.insert(.skipsHiddenFiles)
        }
        guard let enumerator = FileManager.default.enumerator(
            at: request.folderURL,
            includingPropertiesForKeys: keys,
            options: options
        ) else { return [] }
        let basePath = request.folderURL.standardizedFileURL.path
        var files: [(URL, String)] = []
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: Set(keys))
            if values?.isDirectory == true {
                if skippedFolderNames.contains(url.lastPathComponent) {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard values?.isRegularFile == true, (values?.fileSize ?? 0) <= request.maximumFileSize else { continue }
            let path = url.standardizedFileURL.path
            let relativePath = path.hasPrefix(basePath + "/") ? String(path.dropFirst(basePath.count + 1)) : url.lastPathComponent
            guard request.filePattern.matches(relativePath: relativePath) else { continue }
            files.append((url, relativePath))
        }
        return files.sorted { $0.1.localizedStandardCompare($1.1) == .orderedAscending }
    }

    /// Searches one file and returns its matches, or `nil` when the file is binary, unreadable or has no match.
    public static func search(fileURL: URL, relativePath: String, searcher: TextSearcher, limit: Int) -> FileSearchResult? {
        guard let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe),
              let decoded = try? EncodingDetector().decode(data) else { return nil }
        let text = LineEnding.normalize(decoded.text, to: .lf) as NSString
        let ranges = searcher.matches(in: text, limit: limit)
        guard !ranges.isEmpty else { return nil }
        let index = LineIndex(text: text)
        let matches = ranges.map { range -> FileSearchMatch in
            let lineNumber = index.lineNumber(at: range.location)
            let lineRange = index.range(ofLine: lineNumber) ?? NSRange(location: range.location, length: 0)
            let lineText = text.substring(with: lineRange)
            let rangeInLine = NSRange(
                location: range.location - lineRange.location,
                length: min(range.length, max(0, NSMaxRange(lineRange) - range.location))
            )
            return FileSearchMatch(range: range, lineNumber: lineNumber, lineText: lineText, rangeInLine: rangeInLine)
        }
        return FileSearchResult(fileURL: fileURL, relativePath: relativePath, matches: matches)
    }

    /// Streams the results of a folder search file by file; cancelling the consuming task stops the search.
    ///
    /// - Throws: `SearchQueryError` before any file is read when the query is invalid.
    public static func results(for request: FileSearchRequest) throws -> AsyncStream<FileSearchResult> {
        let searcher = try TextSearcher(query: request.query)
        return AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                for file in candidateFiles(for: request) {
                    if Task.isCancelled { break }
                    if let result = search(
                        fileURL: file.url,
                        relativePath: file.relativePath,
                        searcher: searcher,
                        limit: request.maximumMatchesPerFile
                    ) {
                        continuation.yield(result)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
