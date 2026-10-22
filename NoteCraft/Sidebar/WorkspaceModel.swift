import AppKit
import NoteCraftKit
import Observation

enum SidebarSection: String, CaseIterable, Identifiable {
    case files
    case search

    var id: String { rawValue }
}

@MainActor
final class FileNode: Identifiable, Hashable {
    let url: URL
    let name: String
    let isFolder: Bool
    private var cachedChildren: [FileNode]?

    nonisolated var id: URL { url }

    init(url: URL, isFolder: Bool) {
        self.url = url
        self.isFolder = isFolder
        name = url.lastPathComponent
    }

    var children: [FileNode]? {
        guard isFolder else { return nil }
        if let cachedChildren {
            return cachedChildren
        }
        let loaded = Self.children(of: url)
        cachedChildren = loaded
        return loaded
    }

    /// Lists the visible entries of `folderURL`: folders first, then files, in Finder order.
    static func children(of folderURL: URL) -> [FileNode] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return urls.compactMap { url -> FileNode? in
            let values = try? url.resourceValues(forKeys: Set(keys))
            let isFolder = values?.isDirectory == true && values?.isPackage != true
            if isFolder, FileSearcher.skippedFolderNames.contains(url.lastPathComponent) {
                return nil
            }
            return FileNode(url: url, isFolder: isFolder)
        }
        .sorted { lhs, rhs in
            if lhs.isFolder != rhs.isFolder {
                return lhs.isFolder
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    nonisolated static func == (lhs: FileNode, rhs: FileNode) -> Bool {
        lhs.url == rhs.url
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}

@MainActor
@Observable
final class WorkspaceModel {
    static let shared = WorkspaceModel(defaults: .standard)
    static let bookmarkKey = "WorkspaceFolderBookmark"
    static let quickOpenLimit = 20_000

    private(set) var folderURL: URL?
    private(set) var rootNodes: [FileNode] = []
    var selectedSection: SidebarSection = .files
    var filterText = ""
    let fileSearch = FileSearchModel()

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var accessedURL: URL?
    @ObservationIgnored private var cachedFiles: [(url: URL, relativePath: String)]?

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// Opens `url` as the folder of the sidebar and remembers it for the next launch.
    func openFolder(_ url: URL, storesBookmark: Bool = true) {
        stopAccessing()
        if url.startAccessingSecurityScopedResource() {
            accessedURL = url
        }
        folderURL = url
        fileSearch.folderURL = url
        filterText = ""
        reload()
        if storesBookmark, let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            defaults.set(bookmark, forKey: Self.bookmarkKey)
        }
    }

    func closeFolder() {
        stopAccessing()
        folderURL = nil
        rootNodes = []
        cachedFiles = nil
        fileSearch.folderURL = nil
        fileSearch.clear()
        defaults.removeObject(forKey: Self.bookmarkKey)
    }

    /// Reopens the folder remembered from the previous launch.
    func restore() {
        guard let bookmark = defaults.data(forKey: Self.bookmarkKey) else { return }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            defaults.removeObject(forKey: Self.bookmarkKey)
            return
        }
        openFolder(url, storesBookmark: isStale)
    }

    /// Reads the folder contents again.
    func reload() {
        cachedFiles = nil
        rootNodes = folderURL.map(FileNode.children(of:)) ?? []
    }

    var allFiles: [(url: URL, relativePath: String)] {
        if let cachedFiles {
            return cachedFiles
        }
        guard let folderURL else { return [] }
        let request = FileSearchRequest(folderURL: folderURL, query: SearchQuery(text: "*"), maximumFileSize: .max)
        let files = Array(FileSearcher.candidateFiles(for: request).prefix(Self.quickOpenLimit))
        cachedFiles = files
        return files
    }

    var filteredFiles: [(url: URL, relativePath: String)] {
        FuzzyMatcher.rank(allFiles, query: filterText) { $0.relativePath }.prefix(500).map(\.item)
    }

    /// Lets the user pick a folder with an open panel.
    func chooseFolder(for window: NSWindow? = nil) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.Sidebar.openFolder.replacingOccurrences(of: " …", with: "")
        let handler: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated {
                self?.openFolder(url)
            }
        }
        if let window {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(panel.runModal())
        }
    }

    private func stopAccessing() {
        accessedURL?.stopAccessingSecurityScopedResource()
        accessedURL = nil
    }
}

@MainActor
enum DocumentOpener {
    /// Opens `url` in a document window and selects `range` once the editor exists.
    static func open(_ url: URL, selecting range: NSRange? = nil) {
        Task { @MainActor in
            guard let (document, _) = try? await NSDocumentController.shared.openDocument(withContentsOf: url, display: true),
                  let textDocument = document as? TextDocument, let range else { return }
            if let editor = textDocument.editor {
                editor.select(range)
            } else {
                textDocument.pendingSelection = range
            }
        }
    }
}
