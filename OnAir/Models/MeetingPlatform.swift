import Foundation

struct MeetingPlatform: Equatable {

    enum Platform: String, Equatable {
        case googleMeet, zoom, teams, webex, other

        var displayName: String {
            switch self {
            case .googleMeet: return "Google Meet"
            case .zoom: return "Zoom"
            case .teams: return "Teams"
            case .webex: return "Webex"
            case .other: return "Link"
            }
        }
    }

    let platform: Platform
    let url: URL

    private static let platformPatterns: [(Platform, NSRegularExpression)] = {
        let patterns: [(Platform, String)] = [
            (.googleMeet, #"https?://meet\.google\.com/[a-z\-]+"#),
            (.zoom, #"https?://[\w.-]*zoom\.us/[^\s]+"#),
            (.teams, #"https?://teams\.microsoft\.com/l/meetup-join/[^\s]+"#),
            (.webex, #"https?://[\w.-]*\.webex\.com/[^\s]+"#),
        ]
        return patterns.compactMap { platform, pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
            return (platform, regex)
        }
    }()

    private static let genericURLPattern: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"https://[^\s>)\]]+"#, options: .caseInsensitive)
    }()

    static func detect(from text: String?) -> MeetingPlatform? {
        guard let text, !text.isEmpty else { return nil }
        let range = NSRange(text.startIndex..., in: text)

        for (platform, regex) in platformPatterns {
            if let match = regex.firstMatch(in: text, range: range),
               let matchRange = Range(match.range, in: text),
               let url = URL(string: String(text[matchRange])) {
                return MeetingPlatform(platform: platform, url: url)
            }
        }

        if let regex = genericURLPattern,
           let match = regex.firstMatch(in: text, range: range),
           let matchRange = Range(match.range, in: text),
           let url = URL(string: String(text[matchRange])) {
            return MeetingPlatform(platform: .other, url: url)
        }

        return nil
    }
}
