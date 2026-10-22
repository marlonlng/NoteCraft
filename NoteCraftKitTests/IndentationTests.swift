import Foundation
import Testing
@testable import NoteCraftKit

struct IndentationTests {
    @Test func detectsSpaceIndentationWidth() {
        let text = "a {\n  b {\n    c\n  }\n}\nd {\n  e\n}"
        #expect(Indentation.detect(in: text) == Indentation(usesTabs: false, width: 2))
    }

    @Test func detectsFourSpaces() {
        let text = "def a():\n    if b:\n        c\n    d\n"
        #expect(Indentation.detect(in: text) == Indentation(usesTabs: false, width: 4))
    }

    @Test func detectsTabs() {
        #expect(Indentation.detect(in: "a\n\tb\n\tc\n\t\td")?.usesTabs == true)
    }

    @Test func returnsNilWithoutEnoughEvidence() {
        #expect(Indentation.detect(in: "a\nb\n  c") == nil)
    }

    @Test func buildsIndentationUnit() {
        #expect(Indentation(usesTabs: false, width: 3).unit == "   ")
        #expect(Indentation(usesTabs: true, width: 8).unit == "\t")
        #expect(Indentation(usesTabs: false, width: 0).width == 1)
    }

    @Test func readsLeadingWhitespace() {
        let text = "  \tfoo\nbar" as NSString
        #expect(Indentation.leadingWhitespace(ofLineContaining: 5, in: text) == "  \t")
        #expect(Indentation.leadingWhitespace(ofLineContaining: 1, in: text) == " ")
        #expect(Indentation.leadingWhitespace(ofLineContaining: 8, in: text) == "")
    }

    @Test func keepsIndentationOnLineBreak() {
        let result = Indentation(usesTabs: false, width: 4).lineBreak(at: 6, in: "    ab" as NSString)
        #expect(result.text == "\n    ")
        #expect(result.caretOffset == 5)
    }

    @Test func increasesIndentationAfterOpeningBracket() {
        let result = Indentation(usesTabs: false, width: 2).lineBreak(at: 6, in: "if x {" as NSString)
        #expect(result.text == "\n  ")
    }

    @Test func increasesIndentationAfterColon() {
        let result = Indentation(usesTabs: false, width: 4).lineBreak(at: 6, in: "if a: " as NSString)
        #expect(result.text == "\n    ")
    }

    @Test func splitsBracketPairOnLineBreak() {
        let result = Indentation(usesTabs: true, width: 4).lineBreak(at: 5, in: "f() {}" as NSString)
        #expect(result.text == "\n\t\n")
        #expect(result.caretOffset == 2)
    }
}

struct BracketsTests {
    @Test func findsMatchingBracketsInBothDirections() {
        let text = "a(b[c]{d}(e))" as NSString
        #expect(Brackets.matchingBracket(at: 1, in: text) == 12)
        #expect(Brackets.matchingBracket(at: 12, in: text) == 1)
        #expect(Brackets.matchingBracket(at: 3, in: text) == 5)
        #expect(Brackets.matchingBracket(at: 8, in: text) == 6)
    }

    @Test func returnsNilForUnbalancedOrNonBrackets() {
        let text = "(a" as NSString
        #expect(Brackets.matchingBracket(at: 0, in: text) == nil)
        #expect(Brackets.matchingBracket(at: 1, in: text) == nil)
        #expect(Brackets.matchingBracket(at: 9, in: text) == nil)
        #expect(Brackets.matchingBracket(at: 1, in: ")]" as NSString) == nil)
    }

    @Test func mapsBracketPairs() {
        #expect(Brackets.closing(forOpening: 0x7B) == 0x7D)
        #expect(Brackets.opening(forClosing: 0x5D) == 0x5B)
        #expect(Brackets.closing(forOpening: 0x41) == nil)
    }
}

struct AutoPairingTests {
    @Test func pairsBracketsBeforeWhitespaceOrEnd() {
        #expect(AutoPairing.closingCounterpart(for: "(", before: nil, after: "f") == ")")
        #expect(AutoPairing.closingCounterpart(for: "{", before: " ", after: nil) == "}")
        #expect(AutoPairing.closingCounterpart(for: "[", before: ")", after: nil) == "]")
    }

    @Test func doesNotPairBeforeWords() {
        #expect(AutoPairing.closingCounterpart(for: "(", before: "x", after: nil) == nil)
        #expect(AutoPairing.closingCounterpart(for: "a", before: nil, after: nil) == nil)
    }

    @Test func pairsQuotesOnlyOutsideWords() {
        #expect(AutoPairing.closingCounterpart(for: "\"", before: nil, after: " ") == "\"")
        #expect(AutoPairing.closingCounterpart(for: "'", before: nil, after: "n") == nil)
        #expect(AutoPairing.closingCounterpart(for: "\"", before: nil, after: "\"") == nil)
    }

    @Test func skipsOverClosingCharacters() {
        #expect(AutoPairing.shouldSkipOver(")", nextCharacter: ")"))
        #expect(AutoPairing.shouldSkipOver("\"", nextCharacter: "\""))
        #expect(!AutoPairing.shouldSkipOver(")", nextCharacter: "]"))
        #expect(!AutoPairing.shouldSkipOver("a", nextCharacter: "a"))
        #expect(!AutoPairing.shouldSkipOver(")", nextCharacter: nil))
    }

    @Test func deletesEmptyPairs() {
        #expect(AutoPairing.shouldDeletePair(previousCharacter: "(", nextCharacter: ")"))
        #expect(!AutoPairing.shouldDeletePair(previousCharacter: "(", nextCharacter: "]"))
        #expect(!AutoPairing.shouldDeletePair(previousCharacter: nil, nextCharacter: ")"))
    }
}
