import AppKit

@MainActor
final class FolderAccessStore {
    static let shared = FolderAccessStore(defaults: .standard)
    static let bookmarksKey = "PreviewFolderBookmarks"

    private let defaults: UserDefaults
    private(set) var folders: [URL] = []
    private var accessedURLs: [URL] = []

    init(defaults: UserDefaults) {
        self.defaults = defaults
        var isStale = false
        for bookmark in defaults.array(forKey: Self.bookmarksKey) as? [Data] ?? [] {
            guard let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) else {
                continue
            }
            startAccessing(url)
        }
    }

    /// Remembers access to `folderURL` for this and later launches.
    func grant(_ folderURL: URL) {
        guard !covers(folderURL) else { return }
        startAccessing(folderURL)
        var bookmarks = defaults.array(forKey: Self.bookmarksKey) as? [Data] ?? []
        if let bookmark = try? folderURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            bookmarks.append(bookmark)
            defaults.set(bookmarks, forKey: Self.bookmarksKey)
        }
    }

    /// Whether `url` lies inside a folder the user allowed.
    func covers(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return folders.contains { folder in
            let folderPath = folder.standardizedFileURL.path
            return path == folderPath || path.hasPrefix(folderPath.hasSuffix("/") ? folderPath : folderPath + "/")
        }
    }

    /// Forgets every allowed folder.
    func reset() {
        for url in accessedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        accessedURLs = []
        folders = []
        defaults.removeObject(forKey: Self.bookmarksKey)
    }

    private func startAccessing(_ url: URL) {
        if url.startAccessingSecurityScopedResource() {
            accessedURLs.append(url)
        }
        folders.append(url)
    }

    /// Asks the user for access to `folderURL` with an open panel and grants the chosen folder.
    func requestAccess(to folderURL: URL, for window: NSWindow?, completion: @escaping @MainActor () -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = folderURL
        panel.message = L10n.Preview.folderAccessMessage
        panel.prompt = L10n.Preview.allowAccessPrompt
        let handler: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated {
                self?.grant(url)
                completion()
            }
        }
        if let window {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(panel.runModal())
        }
    }
}

@MainActor
final class ExternalContentStore {
    static let shared = ExternalContentStore(defaults: .standard)
    static let documentsKey = "ExternalContentDocuments"

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    private var paths: [String] {
        defaults.stringArray(forKey: Self.documentsKey) ?? []
    }

    /// Whether external content was allowed for the file at `url`.
    func isAllowed(for url: URL?) -> Bool {
        guard let url else { return false }
        return paths.contains(url.standardizedFileURL.path)
    }

    /// Remembers that external content may load for the file at `url`.
    func allow(for url: URL) {
        let path = url.standardizedFileURL.path
        guard !paths.contains(path) else { return }
        defaults.set(paths + [path], forKey: Self.documentsKey)
    }

    /// Forgets every document with allowed external content.
    func reset() {
        defaults.removeObject(forKey: Self.documentsKey)
    }
}
