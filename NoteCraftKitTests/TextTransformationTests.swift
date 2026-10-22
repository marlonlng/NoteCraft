import Foundation
import Testing
@testable import NoteCraftKit

struct TextTransformationTests {
    @Test(arguments: [
        (TextTransformation.sortLinesAscending, "file10\nfile2\nFile1\n", "File1\nfile2\nfile10\n"),
        (.sortLinesDescending, "b\na\nc", "c\nb\na"),
        (.sortLinesByLength, "ccc\na\nbb\nd", "a\nd\nbb\nccc"),
        (.reverseLines, "1\n2\n3", "3\n2\n1"),
        (.removeDuplicateLines, "a\nb\na\nb\nc", "a\nb\nc"),
        (.removeEmptyLines, "a\n\n  \nb", "a\nb"),
        (.trimTrailingWhitespace, "a  \nb\t\n c ", "a\nb\n c"),
        (.trimLeadingWhitespace, "  a\n\tb", "a\nb"),
        (.joinLines, "a\n  b  \n\nc", "a b c"),
        (.uppercase, "straße", "STRASSE"),
        (.lowercase, "ÄBC", "äbc"),
        (.capitalize, "hello world", "Hello World"),
        (.invertCase, "aBß", "AbSS"),
        (.camelCase, "user_first-name", "userFirstName"),
        (.snakeCase, "userFirstName", "user_first_name"),
        (.snakeCase, "parseHTTPResponse", "parse_http_response"),
        (.kebabCase, "  UserFirstName", "  user-first-name"),
        (.base64Encode, "Grüße", "R3LDvMOfZQ=="),
        (.base64Decode, "R3LD vMOfZQ==", "Grüße"),
        (.urlEncode, "a b&c=ä", "a%20b%26c%3D%C3%A4"),
        (.urlDecode, "a+b%26c", "a b&c"),
        (.htmlEscape, "<a href=\"x\">'&'</a>", "&lt;a href=&quot;x&quot;&gt;&#39;&amp;&#39;&lt;/a&gt;"),
        (.htmlUnescape, "&lt;p&gt;&auml;&#228;&#xE4;&unknown;", "<p>äää&unknown;")
    ])
    func transformsText(transformation: TextTransformation, input: String, expected: String) throws {
        #expect(try transformation.apply(to: input) == expected)
    }

    @Test func shufflesWithoutLosingLines() throws {
        let shuffled = try TextTransformation.shuffleLines.apply(to: "1\n2\n3\n4\n")
        #expect(shuffled.hasSuffix("\n"))
        #expect(shuffled.split(separator: "\n").sorted() == ["1", "2", "3", "4"])
    }

    @Test func keepsWordGroupsForEmptyLines() throws {
        #expect(try TextTransformation.snakeCase.apply(to: "fooBar\n\n---") == "foo_bar\n\n---")
    }

    @Test func rejectsInvalidBase64() {
        #expect(throws: TextTransformationError.invalidBase64) {
            try TextTransformation.base64Decode.apply(to: "%%%")
        }
    }

    @Test func rejectsInvalidPercentEncoding() {
        #expect(throws: TextTransformationError.invalidPercentEncoding) {
            try TextTransformation.urlDecode.apply(to: "%E4%")
        }
    }

    @Test func classifiesLineBasedTransformations() {
        #expect(TextTransformation.sortLinesAscending.operatesOnLines)
        #expect(!TextTransformation.uppercase.operatesOnLines)
        #expect(TextTransformation.allCases.filter(\.operatesOnLines).count == 10)
    }

    @Test func splitsIdentifiersIntoWords() {
        #expect(TextTransformation.splitIntoWords("utf8String HTTPServer x") == ["utf8", "String", "HTTP", "Server", "x"])
    }
}

struct JSONFormatterTests {
    @Test func formatsPreservingKeyOrder() throws {
        let formatted = try JSONFormatter().format(#"{"z":1,"a":[true,null,{"k":"v, : {"}],"e":{},"f":[]}"#)
        let expected = """
        {
          "z": 1,
          "a": [
            true,
            null,
            {
              "k": "v, : {"
            }
          ],
          "e": {},
          "f": []
        }
        """
        #expect(formatted == expected)
    }

    @Test func formatsWithCustomIndentation() throws {
        #expect(try JSONFormatter(indentation: "\t").format(#"[1]"#) == "[\n\t1\n]")
    }

    @Test func keepsEscapedQuotesInStrings() throws {
        #expect(try JSONFormatter().minify(#"{ "a" : "x \" y" }"#) == #"{"a":"x \" y"}"#)
    }

    @Test func formatsThroughTransformation() throws {
        #expect(try TextTransformation.formatJSON.apply(to: "[1,2]", indentation: "    ") == "[\n    1,\n    2\n]")
        #expect(try TextTransformation.minifyJSON.apply(to: "[ 1 ,\n 2 ]") == "[1,2]")
    }

    @Test func reportsSyntaxErrorPosition() {
        do {
            _ = try JSONFormatter().format("{\n  \"a\": tru\n}")
            Issue.record("Expected an error")
        } catch let TextTransformationError.invalidJSON(line, column) {
            #expect(line >= 1)
            #expect(column >= 1)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }
}
