import AppKit
import SwiftUI

struct AcknowledgementsView: View {
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
        .frame(minWidth: 560, idealWidth: 620, minHeight: 420, idealHeight: 560)
    }

    /// The license texts of the open-source software bundled with the app.
    static func bundledText(in bundle: Bundle = .main) -> String {
        guard let url = bundle.url(forResource: "Acknowledgements", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return text
    }
}

final class AcknowledgementsWindowController: NSWindowController {
    static let shared = AcknowledgementsWindowController()

    init() {
        let controller = NSHostingController(rootView: AcknowledgementsView(text: AcknowledgementsView.bundledText()))
        let window = NSWindow(contentViewController: controller)
        window.title = L10n.Menu.acknowledgements
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 620, height: 560))
        window.identifier = NSUserInterfaceItemIdentifier("AcknowledgementsWindow")
        window.isRestorable = false
        super.init(window: window)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
