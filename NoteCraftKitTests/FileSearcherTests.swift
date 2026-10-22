import Foundation
import Testing
@testable import NoteCraftKit

struct FilePatternTests {
    @Test(arguments: [
        ("*.swift", "main.swift", true),
        ("*.swift", "main.m", false),
        ("*.SWIFT", "Main.swift", true),
        ("file?.txt", "file1.txt", true),
        ("file?.txt", "file10.txt", false),
        ("Sources/*.swift", "Sources/a.swift", true),
        ("Sources/*.swift", "Sources/x/a.swift", false),
        ("Sources/**.swift", "Sources/x/a.swift", true),
        ("**", "a/b/c", true)
    ])
    func matchesGlobs(pattern: String, name: String, expected: Bool) {
        #expect(FilePattern.glob(pattern, matches: name) == expected)
    }

    @Test func parsesIncludesAndExcludes() {
        let pattern = FilePattern("*.swift, *.md; !*Tests.swift,, ")
        #expect(pattern.includes == ["*.swift", "*.md"])
        #expect(pattern.excludes == ["*Tests.swift"])
        #expect(pattern.matches(relativePath: "Sources/App.swift"))
        #expect(!pattern.matches(relativePath: "Tests/AppTests.swift"))
        #expect(!pattern.matches(relativePath: "image.png"))
    }

    @Test func acceptsEverythingWithoutIncludes() {
        #expect(FilePattern("").matches(relativePath: "any/file.bin"))
        #expect(!FilePattern("!*.log").matches(relativePath: "debug.log"))
    }
}

struct FileSearcherTests {
    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("NoteCraftTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("Sources"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try "let needle = 1\nprint(needle)\n".write(to: folder.appendingPathComponent("Sources/a.swift"), atomically: true, encoding: .utf8)
        try "no match here\r\nNEEDLE in CRLF\r\n".write(to: folder.appendingPathComponent("Sources/b.txt"), atomically: true, encoding: .utf8)
        try "needle".write(to: folder.appendingPathComponent("node_modules/skip.js"), atomically: true, encoding: .utf8)
        try "needle".write(to: folder.appendingPathComponent(".git/config"), atomically: true, encoding: .utf8)
        try Data([0x00, 0x01, 0x6E, 0x65, 0x65, 0x64, 0x6C, 0x65]).write(to: folder.appendingPathComponent("binary.bin"))
        try "Grüße needle".data(using: .isoLatin1)!.write(to: folder.appendingPathComponent("latin1.txt"))
        return folder
    }

    @Test func listsCandidateFilesSkippingIgnoredFolders() throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let request = FileSearchRequest(folderURL: folder, query: SearchQuery(text: "needle"))
        let paths = FileSearcher.candidateFiles(for: request).map(\.relativePath)
        #expect(paths == ["binary.bin", "latin1.txt", "Sources/a.swift", "Sources/b.txt"])
    }

    @Test func respectsFilePatternAndSizeLimit() throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let swiftOnly = FileSearchRequest(folderURL: folder, query: SearchQuery(text: "x"), filePattern: FilePattern("*.swift"))
        #expect(FileSearcher.candidateFiles(for: swiftOnly).map(\.relativePath) == ["Sources/a.swift"])
        let tiny = FileSearchRequest(folderURL: folder, query: SearchQuery(text: "x"), maximumFileSize: 10)
        #expect(FileSearcher.candidateFiles(for: tiny).map(\.relativePath) == ["binary.bin"])
    }

    @Test func searchesSingleFileWithLineInformation() throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let searcher = try TextSearcher(query: SearchQuery(text: "needle"))
        let result = try #require(FileSearcher.search(
            fileURL: folder.appendingPathComponent("Sources/b.txt"),
            relativePath: "Sources/b.txt",
            searcher: searcher,
            limit: 10
        ))
        #expect(result.matches == [
            FileSearchMatch(range: NSRange(location: 14, length: 6), lineNumber: 2, lineText: "NEEDLE in CRLF", rangeInLine: NSRange(location: 0, length: 6))
        ])
        #expect(result.id == result.fileURL)
    }

    @Test func skipsBinaryAndMissingFiles() throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let searcher = try TextSearcher(query: SearchQuery(text: "needle"))
        #expect(FileSearcher.search(fileURL: folder.appendingPathComponent("binary.bin"), relativePath: "binary.bin", searcher: searcher, limit: 10) == nil)
        #expect(FileSearcher.search(fileURL: folder.appendingPathComponent("missing"), relativePath: "missing", searcher: searcher, limit: 10) == nil)
    }

    @Test func streamsResultsForFolder() async throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let request = FileSearchRequest(folderURL: folder, query: SearchQuery(text: "needle", matchesWholeWord: true))
        var results: [FileSearchResult] = []
        for await result in try FileSearcher.results(for: request) {
            results.append(result)
        }
        #expect(results.map(\.relativePath) == ["latin1.txt", "Sources/a.swift", "Sources/b.txt"])
        #expect(results[1].matches.map(\.lineNumber) == [1, 2])
    }

    @Test func rejectsInvalidQueryBeforeSearching() throws {
        let request = FileSearchRequest(folderURL: FileManager.default.temporaryDirectory, query: SearchQuery(text: "[", usesRegularExpression: true))
        #expect(throws: SearchQueryError.invalidRegularExpression(pattern: "[")) {
            _ = try FileSearcher.results(for: request)
        }
    }
}
