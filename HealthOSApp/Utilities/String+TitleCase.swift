import Foundation

extension String {
    /// Trims surrounding whitespace, collapses runs of spaces, and uppercases the
    /// first letter of each word. The rest of each word is left as typed so
    /// acronyms survive ("RDL" stays "RDL", not "Rdl").
    var titleCasedName: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", omittingEmptySubsequences: true)
            .map { word in
                // Capitalize across hyphens too: "t-bar" -> "T-Bar"
                word.split(separator: "-", omittingEmptySubsequences: false)
                    .map { part in
                        guard let first = part.first else { return "" }
                        return String(first).uppercased() + part.dropFirst()
                    }
                    .joined(separator: "-")
            }
            .joined(separator: " ")
    }
}
