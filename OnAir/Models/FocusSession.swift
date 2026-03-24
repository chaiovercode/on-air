import Foundation

struct FocusSession: Codable, Identifiable {
    let id: UUID
    let label: String
    let duration: TimeInterval // planned duration in seconds
    let actualDuration: TimeInterval // how long they actually focused
    let date: Date
    let completed: Bool // did they finish the full duration?

    init(label: String, duration: TimeInterval, actualDuration: TimeInterval, date: Date = Date(), completed: Bool) {
        self.id = UUID()
        self.label = label
        self.duration = duration
        self.actualDuration = actualDuration
        self.date = date
        self.completed = completed
    }
}
