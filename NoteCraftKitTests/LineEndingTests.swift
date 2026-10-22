import Testing
@testable import NoteCraftKit

struct LineEndingTests {
    @Test func detectsDominantLineEnding() {
        let detection = LineEnding.detect(in: "a\r\nb\r\nc\nd")
        #expect(detection.counts[.crlf] == 2)
        #expect(detection.counts[.lf] == 1)
        #expect(detection.dominant == .crlf)
        #expect(detection.isMixed)
    }

    @Test func detectsClassicMacLineEndings() {
        let detection = LineEnding.detect(in: "a\rb\r\rc\r")
        #expect(detection.counts[.cr] == 4)
        #expect(detection.dominant == .cr)
        #expect(!detection.isMixed)
    }

    @Test func reportsNoDominantLineEndingForSingleLine() {
        let detection = LineEnding.detect(in: "single line")
        #expect(detection.dominant == nil)
        #expect(!detection.isMixed)
    }

    @Test(arguments: [
        (LineEnding.lf, "a\nb\nc\nd"),
        (LineEnding.crlf, "a\r\nb\r\nc\r\nd"),
        (LineEnding.cr, "a\rb\rc\rd")
    ])
    func normalizesMixedText(target: LineEnding, expected: String) {
        #expect(LineEnding.normalize("a\r\nb\rc\nd", to: target) == expected)
    }

    @Test func leavesPureLFTextUntouched() {
        #expect(LineEnding.normalize("a\nb", to: .lf) == "a\nb")
    }

    @Test func exposesSequences() {
        #expect(LineEnding.lf.sequence == "\n")
        #expect(LineEnding.crlf.sequence == "\r\n")
        #expect(LineEnding.cr.sequence == "\r")
    }
}
