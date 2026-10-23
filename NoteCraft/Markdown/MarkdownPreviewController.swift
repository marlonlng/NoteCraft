import AppKit
import NoteCraftKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit

@MainActor
protocol MarkdownPreviewDelegate: AnyObject {
    func preview(_ preview: MarkdownPreviewController, didScrollToLine line: Double)
    func preview(_ preview: MarkdownPreviewController, didRequestLine line: Int)
    func preview(_ preview: MarkdownPreviewController, didToggleTaskAtLine line: Int)
    func preview(_ preview: MarkdownPreviewController, didActivateLink address: String)
    func previewDidRequestExternalContent(_ preview: MarkdownPreviewController)
    func preview(_ preview: MarkdownPreviewController, didRequestAccessTo folderURL: URL)
}

struct MarkdownPreviewContent: Equatable {
    var text: String
    var folderURL: URL?
    var allowsExternalImages: Bool
    var styleSheet: MarkdownStyleSheet
}

@MainActor
@Observable
final class MarkdownPreviewState {
    var blockedImageCount = 0
    var inaccessibleFolder: URL?
}

final class PreviewResourceHandler: NSObject, WKURLSchemeHandler {
    /// Serves local images of the document to the preview from the app process, which holds the sandbox access.
    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url, let (data, mimeType) = Self.image(for: url) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        urlSchemeTask.didReceive(URLResponse(url: url, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: nil))
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}

    /// The contents and type of the image file a resource address refers to; other files are refused.
    static func image(for address: URL) -> (Data, String)? {
        guard let fileURL = MarkdownPage.fileURL(forResourceAddress: address),
              let type = UTType(filenameExtension: fileURL.pathExtension), type.conforms(to: .image),
              let data = try? Data(contentsOf: fileURL) else { return nil }
        return (data, type.preferredMIMEType ?? "application/octet-stream")
    }
}

final class PreviewMessageProxy: NSObject, WKScriptMessageHandler {
    weak var controller: MarkdownPreviewController?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        controller?.handleMessage(message.body)
    }
}

final class MarkdownPreviewController: NSViewController, WKNavigationDelegate {
    static let pageURL = URL(string: "\(MarkdownPage.resourceScheme)://preview/")

    let state = MarkdownPreviewState()
    weak var delegate: MarkdownPreviewDelegate?
    var folderAccess: FolderAccessStore
    private(set) var webView: WKWebView!
    private(set) var isLoaded = false
    private(set) var isLoading = false
    private(set) var content: MarkdownPreviewContent?
    private(set) var lastLine: Double = 1
    private var loadedPolicy: Bool?
    private var loadedCSS: String?
    private var pendingUpdate: (html: String, css: String)?
    private let messageProxy = PreviewMessageProxy()
    private let resourceHandler = PreviewResourceHandler()

    init(folderAccess: FolderAccessStore) {
        self.folderAccess = folderAccess
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(resourceHandler, forURLScheme: MarkdownPage.resourceScheme)
        configuration.userContentController.add(messageProxy, name: MarkdownPage.messageHandlerName)
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 400, height: 400), configuration: configuration)
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        webView.setAccessibilityLabel(L10n.Accessibility.preview)
        self.webView = webView
        messageProxy.controller = self

        let banner = NSHostingView(rootView: PreviewBanner(
            state: state,
            onLoadExternalContent: { [weak self] in
                guard let self else { return }
                self.delegate?.previewDidRequestExternalContent(self)
            },
            onAllowFolderAccess: { [weak self] folderURL in
                guard let self else { return }
                self.delegate?.preview(self, didRequestAccessTo: folderURL)
            }
        ))
        banner.sizingOptions = [.intrinsicContentSize]
        banner.setContentHuggingPriority(.required, for: .vertical)
        let stack = NSStackView(views: [banner, webView])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.distribution = .fill
        for subview in stack.arrangedSubviews {
            subview.translatesAutoresizingMaskIntoConstraints = false
            subview.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        webView.setContentHuggingPriority(.defaultLow, for: .vertical)
        view = stack
    }

    isolated deinit {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: MarkdownPage.messageHandlerName)
    }

    /// Renders `content` and shows it, replacing only the document body when the page is already loaded.
    func display(_ content: MarkdownPreviewContent) {
        _ = view
        self.content = content
        let renderer = MarkdownRenderer(
            folderURL: content.folderURL,
            loadsExternalImages: content.allowsExternalImages,
            allowsTaskToggling: true,
            localImageSource: MarkdownPage.resourceAddress(for:)
        )
        let rendering = renderer.render(content.text)
        state.blockedImageCount = rendering.blockedImages.count
        state.inaccessibleFolder = Self.inaccessibleFolder(for: rendering.localImages, documentFolder: content.folderURL, access: folderAccess)
        webView.underPageBackgroundColor = content.styleSheet.theme.background.nsColor
        let css = content.styleSheet.css
        guard loadedPolicy == content.allowsExternalImages, isLoaded || isLoading else {
            load(body: rendering.html, css: css, allowsExternalImages: content.allowsExternalImages)
            return
        }
        guard isLoaded else {
            pendingUpdate = (rendering.html, css)
            return
        }
        apply(html: rendering.html, css: css)
    }

    private func apply(html: String, css: String) {
        if css != loadedCSS {
            loadedCSS = css
            webView.callAsyncJavaScript("NoteCraft.setStyle(css)", arguments: ["css": css], in: nil, in: .page) { _ in }
        }
        webView.callAsyncJavaScript("NoteCraft.update(html)", arguments: ["html": html], in: nil, in: .page) { _ in }
    }

    private func load(body: String, css: String, allowsExternalImages: Bool) {
        isLoaded = false
        isLoading = true
        pendingUpdate = nil
        loadedPolicy = allowsExternalImages
        loadedCSS = css
        let html = MarkdownPage.previewHTML(body: body, css: css, nonce: UUID().uuidString, allowsExternalImages: allowsExternalImages)
        webView.loadHTMLString(html, baseURL: Self.pageURL)
    }

    /// Scrolls the preview so that the block of the one-based source `line` is at the top.
    func scroll(toLine line: Double) {
        lastLine = line
        guard isLoaded else { return }
        webView.callAsyncJavaScript("NoteCraft.scrollToLine(line)", arguments: ["line": line], in: nil, in: .page) { _ in }
    }

    /// The first local image that can't be read and isn't in an allowed folder, reported as the folder to ask access for.
    static func inaccessibleFolder(for images: [URL], documentFolder: URL?, access: FolderAccessStore) -> URL? {
        for image in images where !FileManager.default.isReadableFile(atPath: image.path) && !access.covers(image) {
            if let documentFolder, image.standardizedFileURL.path.hasPrefix(documentFolder.standardizedFileURL.path + "/") {
                return documentFolder
            }
            return image.deletingLastPathComponent()
        }
        return nil
    }

    /// Dispatches a message posted by the preview script.
    func handleMessage(_ body: Any) {
        guard let message = body as? [String: Any], let type = message["type"] as? String else { return }
        let line = (message["line"] as? NSNumber)?.doubleValue
        switch type {
        case "scroll":
            guard let line else { return }
            lastLine = line
            delegate?.preview(self, didScrollToLine: line)
        case "reveal":
            guard let line else { return }
            delegate?.preview(self, didRequestLine: Int(line))
        case "task":
            guard let line else { return }
            delegate?.preview(self, didToggleTaskAtLine: Int(line))
        case "link":
            guard let address = message["href"] as? String else { return }
            delegate?.preview(self, didActivateLink: address)
        default:
            break
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .cancel }
        if url == Self.pageURL || url.absoluteString == "about:blank" {
            return .allow
        }
        if navigationAction.navigationType == .linkActivated {
            delegate?.preview(self, didActivateLink: url.absoluteString)
        }
        return .cancel
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        isLoading = false
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoaded = true
        isLoading = false
        if let pendingUpdate {
            self.pendingUpdate = nil
            apply(html: pendingUpdate.html, css: pendingUpdate.css)
        }
        scroll(toLine: lastLine)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        isLoaded = false
        isLoading = false
        if let content {
            display(content)
        }
    }
}

struct PreviewBanner: View {
    let state: MarkdownPreviewState
    let onLoadExternalContent: () -> Void
    let onAllowFolderAccess: (URL) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if state.blockedImageCount > 0 {
                row(symbol: "network.slash", title: L10n.Preview.externalContentBlocked) {
                    Button(L10n.Preview.loadExternalContent, action: onLoadExternalContent)
                }
            }
            if let folder = state.inaccessibleFolder {
                row(symbol: "folder.badge.questionmark", title: L10n.Preview.folderAccessNeeded) {
                    Button(L10n.Preview.allowFolderAccess) {
                        onAllowFolderAccess(folder)
                    }
                }
            }
        }
        .background(.bar)
    }

    private func row<Action: View>(symbol: String, title: String, @ViewBuilder action: () -> Action) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                action()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .accessibilityElement(children: .contain)
            Divider()
        }
    }
}
