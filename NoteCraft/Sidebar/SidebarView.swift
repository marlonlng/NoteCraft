import AppKit
import NoteCraftKit
import SwiftUI

struct SidebarView: View {
    @Bindable var workspace: WorkspaceModel

    var body: some View {
        VStack(spacing: 0) {
            Picker(L10n.Sidebar.sections, selection: $workspace.selectedSection) {
                Label(L10n.Sidebar.files, systemImage: "folder").tag(SidebarSection.files)
                Label(L10n.Sidebar.search, systemImage: "magnifyingglass").tag(SidebarSection.search)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .labelStyle(.iconOnly)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            switch workspace.selectedSection {
            case .files:
                FileTreeView(workspace: workspace)
            case .search:
                FileSearchView(model: workspace.fileSearch, workspace: workspace)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.Accessibility.sidebar)
    }
}

struct NoFolderView: View {
    let title: String
    let description: String
    let workspace: WorkspaceModel

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "folder")
        } description: {
            Text(description)
        } actions: {
            Button(L10n.Sidebar.openFolder) {
                workspace.chooseFolder(for: NSApp.keyWindow)
            }
        }
        .frame(maxHeight: .infinity)
    }
}

struct FileTreeView: View {
    @Bindable var workspace: WorkspaceModel
    @State private var selection: URL?

    var body: some View {
        if let folderURL = workspace.folderURL {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    Section(folderURL.lastPathComponent) {
                        if workspace.filterText.isEmpty {
                            OutlineGroup(workspace.rootNodes, children: \.children) { node in
                                FileRow(url: node.url, title: node.name)
                            }
                        } else {
                            ForEach(workspace.filteredFiles, id: \.url) { file in
                                FileRow(url: file.url, title: file.relativePath)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .contextMenu(forSelectionType: URL.self) { urls in
                    if let url = urls.first {
                        Button(L10n.Menu.revealInFinder) {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                        Button(L10n.Menu.copyPath) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(url.path, forType: .string)
                        }
                    }
                } primaryAction: { urls in
                    for url in urls where !url.hasDirectoryPath {
                        DocumentOpener.open(url)
                    }
                }

                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField(L10n.Sidebar.filterPlaceholder, text: $workspace.filterText)
                        .textFieldStyle(.plain)
                    Menu {
                        Button(L10n.Sidebar.refresh) { workspace.reload() }
                        Button(L10n.Sidebar.openFolder) { workspace.chooseFolder(for: NSApp.keyWindow) }
                        Divider()
                        Button(L10n.Sidebar.closeFolder) { workspace.closeFolder() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .accessibilityLabel(L10n.Sidebar.folderActions)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
            }
        } else {
            NoFolderView(title: L10n.Sidebar.noFolder, description: L10n.Sidebar.noFolderDescription, workspace: workspace)
        }
    }
}

struct FileRow: View {
    let url: URL
    let title: String

    var body: some View {
        Label {
            Text(title).lineLimit(1).truncationMode(.middle)
        } icon: {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 16, height: 16)
        }
        .tag(url)
        .help(url.path)
    }
}

struct FileSearchView: View {
    @Bindable var model: FileSearchModel
    let workspace: WorkspaceModel
    @FocusState private var isQueryFocused: Bool

    var body: some View {
        if workspace.folderURL == nil {
            NoFolderView(title: L10n.FileSearch.noFolder, description: L10n.FileSearch.noFolderDescription, workspace: workspace)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                TextField(L10n.FileSearch.queryPlaceholder, text: $model.queryText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isQueryFocused)
                    .onSubmit(model.search)
                TextField(L10n.FileSearch.filePatternPlaceholder, text: $model.filePatternText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(model.search)
                HStack(spacing: 2) {
                    Toggle(isOn: $model.isCaseSensitive) {
                        Text(verbatim: "Aa").font(.system(.callout, design: .monospaced))
                    }
                    .help(L10n.Find.caseSensitive)
                    .accessibilityLabel(L10n.Find.caseSensitive)
                    Toggle(isOn: $model.matchesWholeWord) {
                        Text(verbatim: "ab").font(.system(.callout, design: .monospaced)).underline()
                    }
                    .help(L10n.Find.wholeWord)
                    .accessibilityLabel(L10n.Find.wholeWord)
                    Toggle(isOn: $model.usesRegularExpression) {
                        Text(verbatim: ".*").font(.system(.callout, design: .monospaced))
                    }
                    .help(L10n.Find.regularExpression)
                    .accessibilityLabel(L10n.Find.regularExpression)
                    Toggle(isOn: $model.includesHiddenFiles) {
                        Image(systemName: "eye")
                    }
                    .help(L10n.FileSearch.includesHiddenFiles)
                    .accessibilityLabel(L10n.FileSearch.includesHiddenFiles)
                    Spacer()
                    if model.isSearching {
                        ProgressView().controlSize(.small)
                        Button(L10n.FileSearch.cancel, action: model.cancel)
                    } else {
                        Button(L10n.FileSearch.search, action: model.search)
                            .disabled(model.queryText.isEmpty)
                    }
                }
                .toggleStyle(.button)

                if let validationMessage = model.validationMessage {
                    Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                } else if let summary = model.summary {
                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .onChange(of: model.focusRequest, initial: true) {
                isQueryFocused = true
            }

            if model.hasSearched, !model.isSearching, model.results.isEmpty, model.validationMessage == nil {
                ContentUnavailableView(
                    L10n.FileSearch.noResults,
                    systemImage: "magnifyingglass",
                    description: Text(L10n.FileSearch.noResultsDescription)
                )
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(model.results) { result in
                        FileSearchResultSection(result: result) { match in
                            model.open(result, match: match)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }
}

struct FileSearchResultSection: View {
    let result: FileSearchResult
    let onOpen: (FileSearchMatch) -> Void
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(Array(result.matches.enumerated()), id: \.offset) { _, match in
                Button {
                    onOpen(match)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(String(match.lineNumber))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 28, alignment: .trailing)
                        Text(Self.highlighted(match))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(L10n.FileSearch.lineLabel(match.lineNumber)): \(match.lineText)")
            }
        } label: {
            HStack(spacing: 6) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: result.fileURL.path))
                    .resizable()
                    .frame(width: 16, height: 16)
                Text(result.relativePath)
                    .lineLimit(1)
                    .truncationMode(.head)
                Spacer(minLength: 4)
                Text(String(result.matches.count))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .help(result.fileURL.path)
        }
    }

    /// The line text with leading whitespace removed and the match emphasized.
    static func highlighted(_ match: FileSearchMatch) -> AttributedString {
        let line = match.lineText as NSString
        var leading = 0
        while leading < line.length, line.character(at: leading) == 0x20 || line.character(at: leading) == 0x09 {
            leading += 1
        }
        let trimmed = line.substring(from: leading)
        var attributed = AttributedString(trimmed)
        let shifted = NSRange(location: match.rangeInLine.location - leading, length: match.rangeInLine.length)
        if shifted.location >= 0, let range = Range(shifted, in: trimmed),
           let lower = AttributedString.Index(range.lowerBound, within: attributed),
           let upper = AttributedString.Index(range.upperBound, within: attributed) {
            attributed[lower..<upper].font = .body.bold()
            attributed[lower..<upper].backgroundColor = Color.yellow.opacity(0.35)
        }
        return attributed
    }
}
