import Foundation
import NoteCraftKit
import Observation

enum ExternalChange: Equatable {
    case modified
    case deleted
    case reloaded
}

@MainActor
@Observable
final class DocumentAttributes {
    var encoding: TextEncoding
    var lineEnding: LineEnding
    var hasMixedLineEndings = false
    var language: Language = .plainText
    var isLanguageOverridden = false
    var indentation: Indentation
    var isLargeFile = false
    var externalChange: ExternalChange?

    init(settings: EditorSettings) {
        encoding = settings.defaultEncoding
        lineEnding = settings.defaultLineEnding
        indentation = settings.indentation
    }
}

@MainActor
protocol DocumentEditor: AnyObject {
    var selectedRange: NSRange { get }
    func documentWillReplaceContents()
    func documentDidReplaceContents()
    func select(_ range: NSRange)
    func replaceAllText(with text: String, actionName: String)
}
