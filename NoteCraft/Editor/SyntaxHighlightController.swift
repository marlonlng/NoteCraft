import AppKit
import NoteCraftKit

@MainActor
final class SyntaxHighlightController {
    private let textStorage: NSTextStorage
    private weak var layoutManager: NSLayoutManager?
    private var task: Task<Void, Never>?
    private var generation = 0
    private var tokens: [SyntaxToken] = []
    private var colors: [TokenKind: NSColor] = [:]

    var language: Language = .plainText {
        didSet {
            if language != oldValue {
                schedule(after: .zero)
            }
        }
    }

    var isEnabled = true {
        didSet {
            if isEnabled != oldValue {
                schedule(after: .zero)
            }
        }
    }

    var theme: Theme = .paper {
        didSet {
            colors = Dictionary(uniqueKeysWithValues: TokenKind.allCases.map { ($0, theme.color(for: $0).nsColor) })
            applyTokens()
        }
    }

    init(textStorage: NSTextStorage, layoutManager: NSLayoutManager) {
        self.textStorage = textStorage
        self.layoutManager = layoutManager
        colors = Dictionary(uniqueKeysWithValues: TokenKind.allCases.map { ($0, theme.color(for: $0).nsColor) })
    }

    /// Re-highlights shortly after the text changed, coalescing rapid edits.
    func textDidChange() {
        schedule(after: .milliseconds(150))
    }

    /// Tokenizes the current text in the background and applies the colors when the text is still unchanged.
    func schedule(after delay: Duration) {
        task?.cancel()
        generation += 1
        let currentGeneration = generation
        guard isEnabled, language.id != Language.plainText.id,
              let highlighter = SyntaxHighlighterCache.shared.highlighter(for: language) else {
            tokens = []
            applyTokens()
            return
        }
        let text = String(textStorage.string)
        task = Task { [weak self] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled else { return }
            let result = await Task.detached(priority: .userInitiated) {
                highlighter.tokens(in: text)
            }.value
            guard let self, !Task.isCancelled, self.generation == currentGeneration else { return }
            self.tokens = result
            self.applyTokens()
        }
    }

    /// Waits until the scheduled highlighting pass has finished.
    func waitUntilFinished() async {
        await task?.value
    }

    /// The token colors currently applied, for inspection.
    var appliedTokens: [SyntaxToken] {
        tokens
    }

    private func applyTokens() {
        guard let layoutManager else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)
        layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: fullRange)
        for token in tokens where NSMaxRange(token.range) <= fullRange.length {
            if let color = colors[token.kind] {
                layoutManager.addTemporaryAttribute(.foregroundColor, value: color, forCharacterRange: token.range)
            }
        }
    }
}
