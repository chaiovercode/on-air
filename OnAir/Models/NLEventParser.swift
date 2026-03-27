import Foundation

// MARK: - Natural Language Parser

struct ParsedEvent {
    var title: String = ""
    var date: Date?
    var duration: TimeInterval?
    var location: String?
    var recurrence: String?
    var people: [String] = []

    var cleanTitle: String {
        title.isEmpty ? "Untitled Event" : title
    }
}

struct NLEventParser {

    /// Known attendee names for fuzzy matching
    var knownPeople: [String] = []

    func parse(_ input: String) -> ParsedEvent {
        var result = ParsedEvent()
        var remaining = input

        // 1. Extract date FIRST using NSDataDetector — so "at 1pm" is consumed before location parser
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        if let dateMatch = detector?.matches(in: remaining, options: [], range: NSRange(remaining.startIndex..., in: remaining)).first {
            result.date = dateMatch.date
            if let range = Range(dateMatch.range, in: remaining) {
                remaining = remaining.replacingCharacters(in: range, with: " ")
            }
        }

        // 2. Extract duration — "for 30m", "for 1 hour", "for 1.5h", "for 90 min"
        let durationPattern = #"(?:^|\s)for\s+(\d+(?:\.\d+)?)\s*(?:h(?:(?:ou)?rs?)?|m(?:in(?:ute)?s?)?)"#
        if let match = remaining.range(of: durationPattern, options: .regularExpression, range: remaining.startIndex..<remaining.endIndex) {
            let matched = String(remaining[match])
            let numPattern = #"(\d+(?:\.\d+)?)\s*(h|m)"#
            if let numMatch = matched.range(of: numPattern, options: .regularExpression) {
                let numStr = String(matched[numMatch])
                let digits = numStr.components(separatedBy: CharacterSet.letters).joined().trimmingCharacters(in: .whitespaces)
                let isHours = numStr.lowercased().contains("h")
                if let val = Double(digits) {
                    result.duration = isHours ? val * 3600 : val * 60
                }
            }
            remaining = remaining.replacingCharacters(in: match, with: " ")
        }

        // 3. Extract recurrence — "every Monday", "weekly", "daily", "every day"
        let recurrencePatterns: [(pattern: String, label: String)] = [
            (#"(?:^|\s)every\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)"#, ""),
            (#"(?:^|\s)every\s+day"#, "Daily"),
            (#"(?:^|\s)every\s+week"#, "Weekly"),
            (#"(?:^|\s)every\s+month"#, "Monthly"),
            (#"(?:^|\s)\b(daily)\b"#, "Daily"),
            (#"(?:^|\s)\b(weekly)\b"#, "Weekly"),
            (#"(?:^|\s)\b(monthly)\b"#, "Monthly"),
        ]
        for rp in recurrencePatterns {
            if let match = remaining.range(of: rp.pattern, options: [.regularExpression, .caseInsensitive]) {
                let matched = String(remaining[match]).trimmingCharacters(in: .whitespaces)
                if rp.label.isEmpty {
                    let day = matched.replacingOccurrences(of: "every ", with: "", options: .caseInsensitive)
                    result.recurrence = "Every \(day.capitalized)"
                } else {
                    result.recurrence = rp.label
                }
                remaining = remaining.replacingCharacters(in: match, with: " ")
                break
            }
        }

        // 4. Extract people — "with Raj", "with Raj and Sarah"
        // Runs after date removal so "at 1pm" won't interfere
        let peoplePattern = #"(?:^|\s)with\s+(.+?)(?:\s+(?:at|on|in|for|from)\b|$)"#
        if let match = remaining.range(of: peoplePattern, options: [.regularExpression, .caseInsensitive]) {
            let matched = String(remaining[match])
            if let withRange = matched.range(of: "with ", options: .caseInsensitive) {
                let namesStr = String(matched[withRange.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                    // Strip trailing prepositions and conjunctions
                    .replacingOccurrences(of: #"\s+(?:and|or|at|on|in|for|from)\s*$"#, with: "", options: .regularExpression)
                let names = namesStr
                    .replacingOccurrences(of: " and ", with: ", ")
                    .replacingOccurrences(of: " & ", with: ", ")
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && $0.lowercased() != "and" && $0.lowercased() != "or" }
                result.people = names
            }
            remaining = remaining.replacingCharacters(in: match, with: " ")
        }

        // 5. Extract location — "at Blue Bottle", "in Conference Room"
        // Runs after date + people removal
        let locationPattern = #"(?:^|\s)(?:at|in)\s+([A-Z][A-Za-z0-9' ]+)"#
        if let match = remaining.range(of: locationPattern, options: .regularExpression) {
            let matched = String(remaining[match]).trimmingCharacters(in: .whitespaces)
            if let prepRange = matched.range(of: #"^(?:at|in)\s+"#, options: .regularExpression) {
                result.location = String(matched[prepRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
            remaining = remaining.replacingCharacters(in: match, with: " ")
        }

        // 6. Clean remaining text as title
        result.title = remaining
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        return result
    }
}
