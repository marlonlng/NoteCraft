import Foundation

public struct DecodedText: Equatable, Sendable {
    public let text: String
    public let encoding: TextEncoding

    public init(text: String, encoding: TextEncoding) {
        self.text = text
        self.encoding = encoding
    }
}

public struct EncodingDetector: Sendable {
    public let fallbackEncoding: TextEncoding

    public init(fallbackEncoding: TextEncoding = .windows1252) {
        self.fallbackEncoding = fallbackEncoding
    }

    /// Detects the encoding of `data` and decodes it.
    ///
    /// Detection order: byte order mark, UTF-16 without BOM, binary content, strict UTF-8,
    /// declared charset, fallback encoding, ISO Latin 1.
    /// - Throws: `TextEncodingError.binaryContent` when the data does not look like text.
    public func decode(_ data: Data) throws -> DecodedText {
        if data.isEmpty {
            return DecodedText(text: "", encoding: .utf8)
        }
        if let encoding = encodingFromByteOrderMark(data), let text = encoding.decode(data) {
            return DecodedText(text: text, encoding: encoding)
        }
        if let encoding = utf16EncodingWithoutByteOrderMark(data), let text = encoding.decode(data) {
            return DecodedText(text: text, encoding: encoding)
        }
        if containsBinaryContent(data) {
            throw TextEncodingError.binaryContent
        }
        if let text = String(data: data, encoding: .utf8) {
            return DecodedText(text: text, encoding: .utf8)
        }
        if let declared = declaredEncoding(in: data), !declared.isUnicode, let text = declared.decode(data) {
            return DecodedText(text: text, encoding: declared)
        }
        if let text = fallbackEncoding.decode(data) {
            return DecodedText(text: text, encoding: fallbackEncoding)
        }
        guard let text = TextEncoding.isoLatin1.decode(data) else {
            throw TextEncodingError.undecodable(encoding: .isoLatin1)
        }
        return DecodedText(text: text, encoding: .isoLatin1)
    }

    /// Decodes `data` with an encoding chosen by the user.
    ///
    /// - Throws: `TextEncodingError.undecodable` when the bytes are invalid in that encoding.
    public func decode(_ data: Data, as encoding: TextEncoding) throws -> DecodedText {
        guard let text = encoding.decode(data) else {
            throw TextEncodingError.undecodable(encoding: encoding)
        }
        return DecodedText(text: text, encoding: encoding)
    }

    /// Returns the encoding signalled by a byte order mark at the start of `data`.
    public func encodingFromByteOrderMark(_ data: Data) -> TextEncoding? {
        let bytes = [UInt8](data.prefix(4))
        if bytes.starts(with: [0xFF, 0xFE, 0x00, 0x00]) {
            return nil
        }
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
            return .utf8WithBOM
        }
        if bytes.starts(with: [0xFF, 0xFE]) {
            return .utf16LittleEndian
        }
        if bytes.starts(with: [0xFE, 0xFF]) {
            return .utf16BigEndian
        }
        return nil
    }

    /// Recognizes UTF-16 text without byte order mark from the distribution of zero bytes.
    public func utf16EncodingWithoutByteOrderMark(_ data: Data) -> TextEncoding? {
        let sample = [UInt8](data.prefix(4096))
        guard sample.count >= 4 else { return nil }
        var evenZeros = 0
        var oddZeros = 0
        for (index, byte) in sample.enumerated() where byte == 0 {
            if index.isMultiple(of: 2) {
                evenZeros += 1
            } else {
                oddZeros += 1
            }
        }
        let pairs = sample.count / 2
        let threshold = max(1, pairs * 4 / 10)
        if oddZeros >= threshold, evenZeros == 0 {
            return .utf16LittleEndian
        }
        if evenZeros >= threshold, oddZeros == 0 {
            return .utf16BigEndian
        }
        return nil
    }

    /// Whether `data` contains bytes that never occur in text files.
    public func containsBinaryContent(_ data: Data) -> Bool {
        let sample = data.prefix(8192)
        var controlCount = 0
        for byte in sample {
            if byte == 0 {
                return true
            }
            if byte < 0x09 || (byte > 0x0D && byte < 0x20 && byte != 0x1B) {
                controlCount += 1
            }
        }
        return controlCount > max(8, sample.count / 10)
    }

    /// Finds an encoding declared inside the text, e.g. `<?xml encoding="…"?>`, `<meta charset="…">` or `-*- coding: … -*-`.
    public func declaredEncoding(in data: Data) -> TextEncoding? {
        guard let head = String(data: data.prefix(1024), encoding: .isoLatin1) else { return nil }
        let patterns = [
            #"encoding\s*=\s*["']([A-Za-z0-9_\-:.]+)["']"#,
            #"charset\s*=\s*["']?([A-Za-z0-9_\-:.]+)"#,
            #"coding[:=]\s*([A-Za-z0-9_\-.]+)"#,
            #"@charset\s+["']([A-Za-z0-9_\-.]+)["']"#
        ]
        let searchRange = NSRange(head.startIndex..., in: head)
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: head, range: searchRange),
                  let range = Range(match.range(at: 1), in: head) else { continue }
            if let encoding = TextEncoding.encoding(ianaName: String(head[range])) {
                return encoding
            }
        }
        return nil
    }
}
