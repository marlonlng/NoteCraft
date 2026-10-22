import Foundation

public enum LineEnding: String, CaseIterable, Codable, Sendable {
    case lf
    case crlf
    case cr

    public var sequence: String {
        switch self {
        case .lf: "\n"
        case .crlf: "\r\n"
        case .cr: "\r"
        }
    }

    /// Counts every line ending in `text` and reports the dominant one.
    public static func detect(in text: String) -> LineEndingDetection {
        var lf = 0
        var crlf = 0
        var cr = 0
        var previousWasCarriageReturn = false
        for unit in text.utf8 {
            switch unit {
            case 0x0A:
                if previousWasCarriageReturn {
                    crlf += 1
                } else {
                    lf += 1
                }
                previousWasCarriageReturn = false
            case 0x0D:
                if previousWasCarriageReturn {
                    cr += 1
                }
                previousWasCarriageReturn = true
            default:
                if previousWasCarriageReturn {
                    cr += 1
                }
                previousWasCarriageReturn = false
            }
        }
        if previousWasCarriageReturn {
            cr += 1
        }
        return LineEndingDetection(counts: [.lf: lf, .crlf: crlf, .cr: cr])
    }

    /// Replaces every line ending in `text` with the given line ending.
    public static func normalize(_ text: String, to lineEnding: LineEnding) -> String {
        guard text.utf8.contains(0x0D) || lineEnding != .lf else { return text }
        let unified = text
            .replacingOccurrences(of: "\r\n", with: "\n", options: .literal)
            .replacingOccurrences(of: "\r", with: "\n", options: .literal)
        guard lineEnding != .lf else { return unified }
        return unified.replacingOccurrences(of: "\n", with: lineEnding.sequence, options: .literal)
    }
}

public struct LineEndingDetection: Equatable, Sendable {
    public let counts: [LineEnding: Int]

    public init(counts: [LineEnding: Int]) {
        self.counts = counts
    }

    public var dominant: LineEnding? {
        let ranked = LineEnding.allCases
            .map { ($0, counts[$0, default: 0]) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
        return ranked.first?.0
    }

    public var isMixed: Bool {
        counts.values.filter { $0 > 0 }.count > 1
    }
}
