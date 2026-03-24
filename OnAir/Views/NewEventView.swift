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
    @State private var selectedCalendarId: String = ""
    @State private var showCalPicker = false
    @FocusState private var titleFocused: Bool

    private let accentPurple = Color(red: 0.6, green: 0.3, blue: 0.7)
    private let store = EKEventStore()

    // NLP
    private var detectedDate: Date? {
        guard !title.isEmpty else { return nil }
        let d = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        return d?.matches(in: title, options: [], range: NSRange(title.startIndex..., in: title)).first?.date
    }
    private var eventDate: Date { detectedDate ?? Date().addingTimeInterval(1800) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("New Event")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Button { isPresented = false } label: {
                    Text("ESC")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(.white.opacity(0.07)))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 16)

            // Title
            TextField("Try: Team sync tomorrow 3pm", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.9))
                .focused($titleFocused)
                .padding(.bottom, 6)

            // Date feedback
            HStack(spacing: 5) {
                Image(systemName: detectedDate != nil ? "calendar.badge.checkmark" : "calendar")
                    .font(.system(size: 10))
                    .foregroundStyle(detectedDate != nil ? .green.opacity(0.7) : .white.opacity(0.2))
                Text(dateText)
                    .font(.system(size: 11))
                    .foregroundStyle(detectedDate != nil ? .green.opacity(0.6) : .white.opacity(0.2))
            }
            .padding(.bottom, 14)

            // Duration pills
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.25))
                    .frame(width: 18)
                HStack(spacing: 3) {
                    ForEach([(l: "30m", s: 1800.0), (l: "1h", s: 3600.0), (l: "1.5h", s: 5400.0), (l: "2h", s: 7200.0)], id: \.l) { d in
                        Button { duration = d.s } label: {
                            Text(d.l)
                                .font(.system(size: 11, weight: duration == d.s ? .bold : .regular))
                                .foregroundStyle(duration == d.s ? .white : .white.opacity(0.3))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(duration == d.s ? .white.opacity(0.1) : .clear))
                        }.buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 10)

            // Fields
            VStack(alignment: .leading, spacing: 10) {
                field("location", "Add a location", $location)
                field("link", "Meeting link or URL", $meetingLink)
                HStack(spacing: 8) {
                    Image(systemName: "bell").font(.system(size: 12)).foregroundStyle(.white.opacity(0.25)).frame(width: 18)
                    Text("5m before").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                }
                field("doc.text", "Notes, agenda, or prep", $notes)
            }

            Spacer()

            // Divider
            Color.white.opacity(0.06).frame(height: 0.5).padding(.bottom, 12)

            // Footer: calendar + create
            HStack {
                // Custom dropdown
                calendarDropdown

                Spacer()

                Button { createEvent() } label: {
                    HStack(spacing: 4) {
                        Text("Create").font(.system(size: 13, weight: .semibold))
                        Text("⌘↵").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(title.isEmpty ? accentPurple.opacity(0.3) : accentPurple))
                }
                .buttonStyle(.plain)
                .disabled(title.isEmpty)
            }
        }
        .padding(20)
        .onAppear {
            titleFocused = true
            if selectedCalendarId.isEmpty {
                selectedCalendarId = store.defaultCalendarForNewEvents?.calendarIdentifier ?? ""
            }
        }
    }

    // MARK: - Calendar Dropdown

    private var calendarDropdown: some View {
        // Selected calendar button
        Button { showCalPicker.toggle() } label: {
            HStack(spacing: 8) {
                Circle().fill(currentCalColor).frame(width: 8, height: 8)
                Text(shortName(currentCal?.title ?? "Calendar"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8)).foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottomLeading) {
            if showCalPicker {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(writableCalendars, id: \.calendarIdentifier) { cal in
                        Button {
                            selectedCalendarId = cal.calendarIdentifier
                            showCalPicker = false
                        } label: {
                            HStack(spacing: 8) {
                                Circle().fill(Color(cgColor: cal.cgColor)).frame(width: 7, height: 7)
                                Text(shortName(cal.title))
                                    .font(.system(size: 12))
                                    .foregroundStyle(cal.calendarIdentifier == selectedCalendarId ? accentPurple : .white.opacity(0.7))
                                Spacer()
                                if cal.calendarIdentifier == selectedCalendarId {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(accentPurple)
                                }
                            }
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(minWidth: 180)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(red: 0.14, green: 0.14, blue: 0.15)))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
                .offset(x: 5, y: -4)
                .alignmentGuide(.bottom) { d in d[.bottom] + d.height + 4 }
            }
        }
    }

    // MARK: - Helpers

    private var dateText: String {
        if let d = detectedDate {
            let f = DateFormatter(); f.dateFormat = "EEE, d MMM 'at' h:mm a"
            return f.string(from: d)
        }
        return "No date detected — defaults to now"
    }

    private var writableCalendars: [EKCalendar] {
        store.calendars(for: .event).filter { $0.allowsContentModifications }
    }

    private var currentCal: EKCalendar? {
        writableCalendars.first { $0.calendarIdentifier == selectedCalendarId } ?? store.defaultCalendarForNewEvents
    }

    private var currentCalColor: Color {
        if let c = currentCal { return Color(cgColor: c.cgColor) }
        return accentPurple
    }

    private func shortName(_ name: String) -> String {
        name.contains("@") ? String(name.prefix(while: { $0 != "@" })) : name
    }

    private func field(_ icon: String, _ placeholder: String, _ text: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(.white.opacity(0.25)).frame(width: 18)
            TextField(placeholder, text: text).textFieldStyle(.plain).font(.system(size: 13))
        }
    }

    // MARK: - Create

    private func createEvent() {
        guard !title.isEmpty else { return }
        let ekEvent = EKEvent(eventStore: store)
        let clean = stripDate(title)
        ekEvent.title = clean.isEmpty ? title : clean
        ekEvent.startDate = eventDate
        ekEvent.endDate = eventDate.addingTimeInterval(duration)
        if !location.isEmpty { ekEvent.location = location }
        var n = notes
        if !meetingLink.isEmpty { n = n.isEmpty ? meetingLink : "\(n)\n\(meetingLink)" }
        if !n.isEmpty { ekEvent.notes = n }
        ekEvent.addAlarm(EKAlarm(relativeOffset: -300))
        ekEvent.calendar = currentCal ?? store.defaultCalendarForNewEvents
        do { try store.save(ekEvent, span: .thisEvent); appState.refreshEvents(); isPresented = false } catch {}
    }

    private func stripDate(_ t: String) -> String {
        let d = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        guard let m = d?.matches(in: t, options: [], range: NSRange(t.startIndex..., in: t)).first,
              let r = Range(m.range, in: t) else { return t }
        return t.replacingCharacters(in: r, with: "").replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
    }
}
