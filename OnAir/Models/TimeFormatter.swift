import Foundation

enum TimeFormatter {

    /// Formats seconds remaining into a human-readable string.
    ///
    /// Ranges (non-overlapping):
    /// - >= 3600s (60 min):  "2h 15m"
    /// - 300-3599s (5-59 min): "12m"
    /// - 60-299s (1-4m59s): "4m 30s"
    /// - 1-59s: "45s"
    /// - <= 0: "now"
    static func format(seconds: Int) -> String {
        if seconds <= 0 {
            return "now"
        }

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if seconds >= 3600 {
            return "\(hours)h \(minutes)m"
        } else if seconds >= 300 {
            return "\(minutes)m"
        } else if seconds >= 60 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}
