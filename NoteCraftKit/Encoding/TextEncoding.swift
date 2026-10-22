import Foundation

public enum TextEncoding: String, CaseIterable, Codable, Sendable {
    case utf8
    case utf8WithBOM
    case utf16LittleEndian
    case utf16BigEndian
    case windows1252
    case isoLatin1
    case isoLatin9
    case macRoman
    case windows1250
    case isoLatin2
    case windows1251
    case koi8R
    case windows1253
    case windows1254
    case shiftJIS
    case eucJP
    case gb18030
    case big5
    case eucKR

    /// The IANA charset name used in declarations such as `<meta charset>`.
    public var ianaName: String {
        switch self {
        case .utf8, .utf8WithBOM: "utf-8"
        case .utf16LittleEndian: "utf-16le"
        case .utf16BigEndian: "utf-16be"
        case .windows1252: "windows-1252"
        case .isoLatin1: "iso-8859-1"
        case .isoLatin9: "iso-8859-15"
        case .macRoman: "macintosh"
        case .windows1250: "windows-1250"
        case .isoLatin2: "iso-8859-2"
        case .windows1251: "windows-1251"
        case .koi8R: "koi8-r"
        case .windows1253: "windows-1253"
        case .windows1254: "windows-1254"
        case .shiftJIS: "shift_jis"
        case .eucJP: "euc-jp"
        case .gb18030: "gb18030"
        case .big5: "big5"
        case .eucKR: "euc-kr"
        }
    }

    /// The Foundation encoding used to convert between bytes and strings.
    public var stringEncoding: String.Encoding {
        switch self {
        case .utf8, .utf8WithBOM: .utf8
        case .utf16LittleEndian: .utf16LittleEndian
        case .utf16BigEndian: .utf16BigEndian
        case .windows1252: .windowsCP1252
        case .isoLatin1: .isoLatin1
        case .isoLatin9: Self.coreFoundationEncoding(.isoLatin9)
        case .macRoman: .macOSRoman
        case .windows1250: .windowsCP1250
        case .isoLatin2: .isoLatin2
        case .windows1251: .windowsCP1251
        case .koi8R: Self.coreFoundationEncoding(.KOI8_R)
        case .windows1253: .windowsCP1253
        case .windows1254: .windowsCP1254
        case .shiftJIS: .shiftJIS
        case .eucJP: .japaneseEUC
        case .gb18030: Self.coreFoundationEncoding(.GB_18030_2000)
        case .big5: Self.coreFoundationEncoding(.big5)
        case .eucKR: Self.coreFoundationEncoding(.EUC_KR)
        }
    }

    /// The byte order mark written in front of the encoded text, if any.
    public var byteOrderMark: [UInt8] {
        switch self {
        case .utf8WithBOM: [0xEF, 0xBB, 0xBF]
        case .utf16LittleEndian: [0xFF, 0xFE]
        case .utf16BigEndian: [0xFE, 0xFF]
        default: []
        }
    }

    /// Whether every Unicode character can be represented in this encoding.
    public var isUnicode: Bool {
        switch self {
        case .utf8, .utf8WithBOM, .utf16LittleEndian, .utf16BigEndian: true
        default: false
        }
    }

    /// Resolves an IANA charset name such as `ISO-8859-1` or `utf8` to a supported encoding.
    public static func encoding(ianaName: String) -> TextEncoding? {
        let normalized = ianaName
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'")))
            .lowercased()
        let aliases: [String: TextEncoding] = [
            "utf8": .utf8,
            "utf-16": .utf16LittleEndian,
            "latin1": .isoLatin1,
            "latin-1": .isoLatin1,
            "cp1252": .windows1252,
            "x-mac-roman": .macRoman,
            "mac": .macRoman,
            "sjis": .shiftJIS,
            "x-sjis": .shiftJIS,
            "gbk": .gb18030,
            "gb2312": .gb18030,
            "us-ascii": .utf8,
            "ascii": .utf8
        ]
        if let alias = aliases[normalized] {
            return alias
        }
        return allCases.first { $0.ianaName == normalized && $0 != .utf8WithBOM }
    }

    /// Encodes `text` including the byte order mark.
    ///
    /// - Throws: `TextEncodingError.unrepresentableCharacter` naming the first character that cannot be encoded.
    public func encode(_ text: String) throws -> Data {
        guard let body = text.data(using: stringEncoding, allowLossyConversion: false) else {
            throw unrepresentableCharacterError(in: text)
        }
        var data = Data(byteOrderMark)
        data.append(body)
        return data
    }

    /// Decodes `data` that is known to use this encoding, skipping a matching byte order mark.
    public func decode(_ data: Data) -> String? {
        var payload = data
        let mark = byteOrderMark.isEmpty && self == .utf8 ? [0xEF, 0xBB, 0xBF] : byteOrderMark
        if !mark.isEmpty, data.starts(with: mark) {
            payload = data.dropFirst(mark.count)
        }
        return String(data: payload, encoding: stringEncoding)
    }

    private func unrepresentableCharacterError(in text: String) -> TextEncodingError {
        var line = 1
        var column = 1
        for character in text {
            if !String(character).canBeConverted(to: stringEncoding) {
                return .unrepresentableCharacter(character: character, line: line, column: column, encoding: self)
            }
            if character == "\n" || character == "\r\n" || character == "\r" {
                line += 1
                column = 1
            } else {
                column += 1
            }
        }
        return .unrepresentableCharacter(character: nil, line: line, column: column, encoding: self)
    }

    private static func coreFoundationEncoding(_ encoding: CFStringEncodings) -> String.Encoding {
        String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(encoding.rawValue)))
    }
}

public enum TextEncodingError: Error, Equatable, Sendable {
    case unrepresentableCharacter(character: Character?, line: Int, column: Int, encoding: TextEncoding)
    case undecodable(encoding: TextEncoding)
    case binaryContent
}
