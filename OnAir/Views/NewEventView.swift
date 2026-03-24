import SwiftUI
import EventKit

struct NewEventView: View {

    @ObservedObject var appState: AppState
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var location = ""
    @State private var meetingLink = ""
    @State private var notes = ""
    @State private var duration: TimeInterval = 1800
    @State private var selectedCalendarId: String?
    @State private var showCalendarPicker = false
    @FocusState private var titleFocused: Bool

    private let accentPurple = Color(red: 0.6, green: 0.3, blue: 0.7)

    // NLP-detected date from title
    private var detectedDate: Date? {
        guard !title.isEmpty else { return nil }
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(title.startIndex..., in: title)
        let matches = detector?.matches(in: title, options: [], range: range) ?? []
        return matches.first?.date
    }

    private var eventDate: Date {
        detectedDate ?? Date().addingTimeInterval(1800)
    }

    private var detectedDateText: String {
        if let date = detectedDate {
            let f = DateFormatter()
            f.dateFormat = "EEE, d MMM 'at' h:mm a"
            return f.string(from: date)
        }
        return "No date detected — defaults to now"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("New Event")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Button { isPresented = false } label: {
                    Text("ESC")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 14)

            // Title — NLP enabled
            TextField("Try: Team sync every Monday 10am", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.85))
                .focused($titleFocused)
                .padding(.bottom, 6)

            // Detected date feedback
            HStack(spacing: 6) {
                Image(systemName: detectedDate != nil ? "calendar.badge.checkmark" : "calendar")
                    .font(.system(size: 10))
                    .foregroundStyle(detectedDate != nil ? .green.opacity(0.7) : .white.opacity(0.2))
                Text(detectedDateText)
                    .font(.system(size: 11))
                    .foregroundStyle(detectedDate != nil ? .green.opacity(0.6) : .white.opacity(0.25))
            }
            .padding(.bottom, 12)

            // Duration
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(width: 18)
                HStack(spacing: 2) {
                    ForEach([("30m", 1800.0), ("1h", 3600.0), ("1.5h", 5400.0), ("2h", 7200.0)], id: \.0) { label, secs in
                        Button {
                            duration = secs
                        } label: {
                            Text(label)
                                .font(.system(size: 11, weight: duration == secs ? .bold : .regular))
                                .foregroundStyle(duration == secs ? .white : .white.opacity(0.35))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(duration == secs ? .white.opacity(0.1) : .clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 8)

            // Fields
            VStack(alignment: .leading, spacing: 8) {
                fieldRow("location", placeholder: "Add a location", text: $location)
                fieldRow("link", placeholder: "Meeting link or URL", text: $meetingLink)

                HStack(spacing: 10) {
                    Image(systemName: "bell")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.3))
                        .frame(width: 20)
                    Text("5m before")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }

                fieldRow("doc.text", placeholder: "Notes, agenda, or prep", text: $notes)
            }

            Spacer().frame(height: 14)

            // Calendar picker
            if showCalendarPicker {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(availableCalendars, id: \.calendarIdentifier) { cal in
                        Button {
                            selectedCalendarId = cal.calendarIdentifier
                            showCalendarPicker = false
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(cgColor: cal.cgColor))
                                    .frame(width: 8, height: 8)
                                Text(shortName(cal.title))
                                    .font(.system(size: 13))
                                    .foregroundStyle(selectedCalendarId == cal.calendarIdentifier ? accentPurple : .white.opacity(0.7))
                                Spacer()
                                if selectedCalendarId == cal.calendarIdentifier || (selectedCalendarId == nil && cal == EKEventStore().defaultCalendarForNewEvents) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(accentPurple)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 10)
            }

            // Footer
            Color.white.opacity(0.06).frame(height: 0.5).padding(.bottom, 10)

            HStack {
                Button {
                    showCalendarPicker.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(selectedCalendarColor)
                            .frame(width: 8, height: 8)
                        Text(selectedCalendarShortName)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: 120, alignment: .leading)

                Spacer()

                Button { createEvent() } label: {
                    HStack(spacing: 4) {
                        Text("Create")
                            .font(.system(size: 13, weight: .semibold))
                        Text("⌘↵")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(title.isEmpty ? accentPurple.opacity(0.3) : accentPurple)
                    )
                }
                .buttonStyle(.plain)
                .disabled(title.isEmpty)
            }
        }
        .padding(18)
        .onAppear { titleFocused = true }
        .onExitCommand { isPresented = false }
    }

    // MARK: - Components

    private func fieldRow(_ icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.3))
                .frame(width: 20)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
    }

    private var availableCalendars: [EKCalendar] {
        EKEventStore().calendars(for: .event).filter { $0.allowsContentModifications }
    }

    private var selectedCalendar: EKCalendar? {
        let store = EKEventStore()
        if let id = selectedCalendarId {
            return store.calendars(for: .event).first { $0.calendarIdentifier == id }
        }
        return store.defaultCalendarForNewEvents
    }

    private var selectedCalendarShortName: String {
        shortName(selectedCalendar?.title ?? "Calendar")
    }

    private var selectedCalendarColor: Color {
        if let cal = selectedCalendar {
            return Color(cgColor: cal.cgColor)
        }
        return accentPurple
    }

    private func shortName(_ name: String) -> String {
        if name.contains("@") { return String(name.prefix(while: { $0 != "@" })) }
        return name
    }

    // MARK: - Create

    private func createEvent() {
        guard !title.isEmpty else { return }

        let store = EKEventStore()
        let ekEvent = EKEvent(eventStore: store)

        // Strip date text from title for cleaner event name
        let cleanTitle = stripDateFromTitle(title)
        ekEvent.title = cleanTitle.isEmpty ? title : cleanTitle

        ekEvent.startDate = eventDate
        ekEvent.endDate = eventDate.addingTimeInterval(duration)
        if !location.isEmpty { ekEvent.location = location }

        var eventNotes = notes
        if !meetingLink.isEmpty {
            eventNotes = eventNotes.isEmpty ? meetingLink : "\(eventNotes)\n\(meetingLink)"
        }
        if !eventNotes.isEmpty { ekEvent.notes = eventNotes }

        // Add 5-minute alarm
        ekEvent.addAlarm(EKAlarm(relativeOffset: -300))
        if let id = selectedCalendarId,
           let cal = store.calendars(for: .event).first(where: { $0.calendarIdentifier == id }) {
            ekEvent.calendar = cal
        } else {
            ekEvent.calendar = store.defaultCalendarForNewEvents
        }

        do {
            try store.save(ekEvent, span: .thisEvent)
            appState.refreshEvents()
            isPresented = false
        } catch {
            // Silent fail
        }
    }

    private func stripDateFromTitle(_ text: String) -> String {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        guard let matches = detector?.matches(in: text, options: [], range: range),
              let match = matches.first else { return text }

        var result = text
        if let swiftRange = Range(match.range, in: text) {
            result = text.replacingCharacters(in: swiftRange, with: "")
        }
        // Clean up leftover prepositions and whitespace
        return result
            .replacingOccurrences(of: "  ", with: " ")
            .replacingOccurrences(of: " at ", with: " ")
            .replacingOccurrences(of: " on ", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}
