import Foundation
import NoteCraftKit

extension TextEncoding {
    var displayName: String {
        switch self {
        case .utf8: String(localized: "Unicode (UTF-8)")
        case .utf8WithBOM: String(localized: "Unicode (UTF-8 with BOM)")
        case .utf16LittleEndian: String(localized: "Unicode (UTF-16 Little Endian)")
        case .utf16BigEndian: String(localized: "Unicode (UTF-16 Big Endian)")
        case .windows1252: String(localized: "Western (Windows-1252)")
        case .isoLatin1: String(localized: "Western (ISO 8859-1)")
        case .isoLatin9: String(localized: "Western (ISO 8859-15)")
        case .macRoman: String(localized: "Western (Mac OS Roman)")
        case .windows1250: String(localized: "Central European (Windows-1250)")
        case .isoLatin2: String(localized: "Central European (ISO 8859-2)")
        case .windows1251: String(localized: "Cyrillic (Windows-1251)")
        case .koi8R: String(localized: "Cyrillic (KOI8-R)")
        case .windows1253: String(localized: "Greek (Windows-1253)")
        case .windows1254: String(localized: "Turkish (Windows-1254)")
        case .shiftJIS: String(localized: "Japanese (Shift JIS)")
        case .eucJP: String(localized: "Japanese (EUC-JP)")
        case .gb18030: String(localized: "Chinese, Simplified (GB 18030)")
        case .big5: String(localized: "Chinese, Traditional (Big 5)")
        case .eucKR: String(localized: "Korean (EUC-KR)")
        }
    }

    var shortName: String {
        switch self {
        case .utf8: "UTF-8"
        case .utf8WithBOM: "UTF-8 BOM"
        case .utf16LittleEndian: "UTF-16 LE"
        case .utf16BigEndian: "UTF-16 BE"
        case .windows1252: "Windows-1252"
        case .isoLatin1: "ISO 8859-1"
        case .isoLatin9: "ISO 8859-15"
        case .macRoman: "Mac OS Roman"
        case .windows1250: "Windows-1250"
        case .isoLatin2: "ISO 8859-2"
        case .windows1251: "Windows-1251"
        case .koi8R: "KOI8-R"
        case .windows1253: "Windows-1253"
        case .windows1254: "Windows-1254"
        case .shiftJIS: "Shift JIS"
        case .eucJP: "EUC-JP"
        case .gb18030: "GB 18030"
        case .big5: "Big 5"
        case .eucKR: "EUC-KR"
        }
    }

    static var menuGroups: [[TextEncoding]] {
        [
            [.utf8, .utf8WithBOM, .utf16LittleEndian, .utf16BigEndian],
            [.windows1252, .isoLatin1, .isoLatin9, .macRoman],
            [.windows1250, .isoLatin2, .windows1251, .koi8R, .windows1253, .windows1254],
            [.shiftJIS, .eucJP, .gb18030, .big5, .eucKR]
        ]
    }
}

extension LineEnding {
    var displayName: String {
        switch self {
        case .lf: String(localized: "LF – macOS and Linux")
        case .crlf: String(localized: "CRLF – Windows")
        case .cr: String(localized: "CR – Classic Mac OS")
        }
    }

    var shortName: String {
        switch self {
        case .lf: "LF"
        case .crlf: "CRLF"
        case .cr: "CR"
        }
    }
}

extension Language {
    var displayName: String {
        id == Language.plainText.id ? String(localized: "Plain Text") : name
    }
}

extension Theme {
    var displayName: String {
        switch id {
        case Theme.paper.id: String(localized: "Paper")
        case Theme.sage.id: String(localized: "Sage")
        case Theme.highContrastLight.id: String(localized: "High Contrast Light")
        case Theme.graphite.id: String(localized: "Graphite")
        case Theme.midnight.id: String(localized: "Midnight")
        case Theme.highContrastDark.id: String(localized: "High Contrast Dark")
        default: id
        }
    }
}

extension TextEncodingError: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .unrepresentableCharacter(character, line, column, encoding):
            L10n.Alert.unrepresentableCharacter(character: character, line: line, column: column, encoding: encoding.shortName)
        case let .undecodable(encoding):
            L10n.Alert.undecodable(encoding: encoding.shortName)
        case .binaryContent:
            L10n.Alert.binaryFileTitle
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .unrepresentableCharacter:
            L10n.Alert.unrepresentableRecovery
        case .undecodable:
            L10n.Alert.undecodableRecovery
        case .binaryContent:
            L10n.Alert.binaryFileMessage
        }
    }
}

extension TextTransformationError: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidBase64: L10n.Alert.invalidBase64
        case .invalidPercentEncoding: L10n.Alert.invalidPercentEncoding
        case let .invalidJSON(line, column): L10n.Alert.invalidJSON(line: line, column: column)
        }
    }
}

extension SearchQueryError: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptyQuery: nil
        case .invalidRegularExpression: L10n.Find.invalidRegularExpression
        }
    }
}
