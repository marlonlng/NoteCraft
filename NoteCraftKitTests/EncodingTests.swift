import Foundation
import Testing
@testable import NoteCraftKit

struct TextEncodingTests {
    @Test func encodesWithByteOrderMark() throws {
        #expect(try TextEncoding.utf8WithBOM.encode("A") == Data([0xEF, 0xBB, 0xBF, 0x41]))
        #expect(try TextEncoding.utf16LittleEndian.encode("A") == Data([0xFF, 0xFE, 0x41, 0x00]))
        #expect(try TextEncoding.utf16BigEndian.encode("A") == Data([0xFE, 0xFF, 0x00, 0x41]))
        #expect(try TextEncoding.utf8.encode("A") == Data([0x41]))
    }

    @Test func reportsFirstUnrepresentableCharacter() {
        #expect(throws: TextEncodingError.unrepresentableCharacter(character: "€", line: 2, column: 3, encoding: .isoLatin1)) {
            try TextEncoding.isoLatin1.encode("abc\nab€")
        }
    }

    @Test func roundTripsAllEncodingsForASCII() throws {
        for encoding in TextEncoding.allCases {
            let data = try encoding.encode("Hello, World!")
            #expect(encoding.decode(data) == "Hello, World!", "\(encoding)")
        }
    }

    @Test func resolvesIANANamesAndAliases() {
        #expect(TextEncoding.encoding(ianaName: "UTF-8") == .utf8)
        #expect(TextEncoding.encoding(ianaName: "\"ISO-8859-1\"") == .isoLatin1)
        #expect(TextEncoding.encoding(ianaName: "latin1") == .isoLatin1)
        #expect(TextEncoding.encoding(ianaName: "Shift_JIS") == .shiftJIS)
        #expect(TextEncoding.encoding(ianaName: "cp1252") == .windows1252)
        #expect(TextEncoding.encoding(ianaName: "klingon") == nil)
    }

    @Test func distinguishesUnicodeEncodings() {
        #expect(TextEncoding.utf16BigEndian.isUnicode)
        #expect(!TextEncoding.macRoman.isUnicode)
    }

    @Test func providesDistinctIANANames() {
        let names = TextEncoding.allCases.filter { $0 != .utf8WithBOM }.map(\.ianaName)
        #expect(Set(names).count == names.count)
    }
}

struct EncodingDetectorTests {
    let detector = EncodingDetector()

    @Test func decodesEmptyDataAsUTF8() throws {
        #expect(try detector.decode(Data()) == DecodedText(text: "", encoding: .utf8))
    }

    @Test func detectsByteOrderMarks() throws {
        #expect(try detector.decode(Data([0xEF, 0xBB, 0xBF, 0x68, 0x69])) == DecodedText(text: "hi", encoding: .utf8WithBOM))
        #expect(try detector.decode(Data([0xFF, 0xFE, 0x68, 0x00])) == DecodedText(text: "h", encoding: .utf16LittleEndian))
        #expect(try detector.decode(Data([0xFE, 0xFF, 0x00, 0x68])) == DecodedText(text: "h", encoding: .utf16BigEndian))
    }

    @Test func ignoresUTF32ByteOrderMark() {
        #expect(detector.encodingFromByteOrderMark(Data([0xFF, 0xFE, 0x00, 0x00])) == nil)
    }

    @Test func detectsUTF16WithoutByteOrderMark() throws {
        let little = "Hallo Welt".data(using: .utf16LittleEndian)!
        let big = "Hallo Welt".data(using: .utf16BigEndian)!
        #expect(try detector.decode(little).encoding == .utf16LittleEndian)
        #expect(try detector.decode(big).encoding == .utf16BigEndian)
    }

    @Test func detectsValidUTF8() throws {
        let decoded = try detector.decode("Grüße 😀".data(using: .utf8)!)
        #expect(decoded == DecodedText(text: "Grüße 😀", encoding: .utf8))
    }

    @Test func fallsBackToWindows1252() throws {
        let data = "Grüße €".data(using: .windowsCP1252)!
        #expect(try detector.decode(data) == DecodedText(text: "Grüße €", encoding: .windows1252))
    }

    @Test func usesConfiguredFallbackEncoding() throws {
        let data = "Größe".data(using: .macOSRoman)!
        let decoded = try EncodingDetector(fallbackEncoding: .macRoman).decode(data)
        #expect(decoded == DecodedText(text: "Größe", encoding: .macRoman))
    }

    @Test func fallsBackToLatin1WhenFallbackCannotDecode() throws {
        let data = Data([0x61, 0x81, 0x62])
        let decoded = try EncodingDetector(fallbackEncoding: .utf8).decode(data)
        #expect(decoded.encoding == .isoLatin1)
    }

    @Test func honorsDeclaredCharset() throws {
        var data = Data("<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><a>".utf8)
        data.append(contentsOf: [0xE4])
        data.append(Data("</a>".utf8))
        #expect(try detector.decode(data).encoding == .isoLatin1)
    }

    @Test func findsDeclarationsInDifferentSyntaxes() {
        #expect(detector.declaredEncoding(in: Data("<meta charset=windows-1251>".utf8)) == .windows1251)
        #expect(detector.declaredEncoding(in: Data("# -*- coding: latin-1 -*-".utf8)) == .isoLatin1)
        #expect(detector.declaredEncoding(in: Data("@charset \"koi8-r\";".utf8)) == .koi8R)
        #expect(detector.declaredEncoding(in: Data("plain".utf8)) == nil)
    }

    @Test func rejectsBinaryData() {
        #expect(throws: TextEncodingError.binaryContent) {
            try detector.decode(Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0x0D, 0x0A, 0x1A, 0x0A, 0x01, 0x02]))
        }
        #expect(detector.containsBinaryContent(Data([UInt8](repeating: 0x01, count: 200))))
        #expect(!detector.containsBinaryContent(Data("\u{1B}[31mred\u{1B}[0m\n".utf8)))
    }

    @Test func decodesWithExplicitEncoding() throws {
        let data = "Größe".data(using: .isoLatin1)!
        #expect(try detector.decode(data, as: .isoLatin1).text == "Größe")
        #expect(throws: TextEncodingError.undecodable(encoding: .utf8)) {
            try detector.decode(data, as: .utf8)
        }
    }
}
