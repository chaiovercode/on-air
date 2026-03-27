import SwiftUI
import EventKit

// MARK: - New Event View

struct NewEventView: View {

    @ObservedObject var appState: AppState
    @Binding var isPresented: Bool

    @State private var rawInput = ""
    @State private var location = ""
    @State private var meetingLink = ""
    @State private var notes = ""
    @State private var duration: TimeInterval = 1800
    @State private var selectedCalendarId: String = ""
    @State private var showCalPicker = false
    @State private var durationManuallySet = false
    @FocusState private var titleFocused: Bool

    private var accentColor: Color { Color(hex: appState.settings.accentColorHex) }
    private let store = EKEventStore()

    private var parsed: ParsedEvent {
        let parser = NLEventParser(knownPeople: appState.statsService.topAttendees.map(\.name))
        return parser.parse(rawInput)
    }

    private var effectiveDate: Date { parsed.date ?? Date().addingTimeInterval(1800) }
    private var effectiveDuration: TimeInterval { durationManuallySet ? duration : (parsed.duration ?? duration) }
    private var effectiveLocation: String { location.isEmpty ? (parsed.location ?? "") : location }

    private var hasAnyParsed: Bool {
        parsed.date != nil || parsed.duration != nil || parsed.location != nil ||
        parsed.recurrence != nil || !parsed.people.isEmpty
    }

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

            // Natural language input
            TextField("Team sync tomorrow 3pm for 1h at Office", text: $rawInput)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.9))
                .focused($titleFocused)
                .onChange(of: rawInput) { _ in
                    // If parser found a duration and user hasn't manually overridden
                    if !durationManuallySet, let d = parsed.duration {
                        duration = d
                    }
                }
                .padding(.bottom, 8)

            // Parsed tokens preview
            if hasAnyParsed {
                parsedTokens
                    .padding(.bottom, 12)
            } else if !rawInput.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("Defaults to 30 min from now")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.2))
                }
                .padding(.bottom, 12)
            }

            // Duration pills
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.25))
                    .frame(width: 18)
                HStack(spacing: 3) {
                    ForEach([(l: "30m", s: 1800.0), (l: "1h", s: 3600.0), (l: "1.5h", s: 5400.0), (l: "2h", s: 7200.0)], id: \.l) { d in
                        Button {
                            duration = d.s
                            durationManuallySet = true
                        } label: {
                            Text(d.l)
                                .font(.system(size: 11, weight: effectiveDuration == d.s ? .bold : .regular))
                                .foregroundStyle(effectiveDuration == d.s ? .white : .white.opacity(0.3))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(effectiveDuration == d.s ? .white.opacity(0.1) : .clear))
                        }.buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 10)

            // Fields
            VStack(alignment: .leading, spacing: 10) {
                field("location",
                      parsed.location != nil && location.isEmpty ? "\(parsed.location!) (from input)" : "Add a location",
                      $location, prefill: nil)
                field("link", "Meeting link or URL", $meetingLink, prefill: nil)
                HStack(spacing: 8) {
                    Image(systemName: "bell").font(.system(size: 12)).foregroundStyle(.white.opacity(0.25)).frame(width: 18)
                    Text("5m before").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                }
                field("doc.text", "Notes, agenda, or prep", $notes, prefill: nil)
            }

            Spacer()

            // Divider
            Color.white.opacity(0.06).frame(height: 0.5).padding(.bottom, 12)

            // Footer: calendar + create
            HStack {
                calendarDropdown
                Spacer()
                Button { createEvent() } label: {
                    HStack(spacing: 4) {
                        Text("Create").font(.system(size: 13, weight: .semibold))
                        Text("\u{2318}\u{21A9}").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(rawInput.isEmpty ? accentColor.opacity(0.3) : accentColor))
                }
                .buttonStyle(.plain)
                .disabled(rawInput.isEmpty)
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

    // MARK: - Parsed Tokens

    private var parsedTokens: some View {
        FlowLayout(spacing: 6) {
            if let date = parsed.date {
                tokenView(icon: "calendar", text: formatDate(date), color: .green)
            }
            if let dur = parsed.duration {
                tokenView(icon: "clock", text: formatDuration(dur), color: .orange)
            }
            if let loc = parsed.location {
                tokenView(icon: "mappin", text: loc, color: .blue)
            }
            if let rec = parsed.recurrence {
                tokenView(icon: "repeat", text: rec, color: .purple)
            }
            ForEach(parsed.people, id: \.self) { person in
                tokenView(icon: "person", text: person, color: .cyan)
            }
        }
    }

    private func tokenView(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(color.opacity(0.12))
        )
    }

    // MARK: - Calendar Dropdown

    private var calendarDropdown: some View {
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
                                    .foregroundStyle(cal.calendarIdentifier == selectedCalendarId ? accentColor : .white.opacity(0.7))
                                Spacer()
                                if cal.calendarIdentifier == selectedCalendarId {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(accentColor)
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

    private func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE, d MMM 'at' h:mm a"
        return f.string(from: d)
    }

    private func formatDuration(_ secs: TimeInterval) -> String {
        let mins = Int(secs / 60)
        if mins >= 60 {
            let h = mins / 60
            let m = mins % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(mins)m"
    }

    private var writableCalendars: [EKCalendar] {
        store.calendars(for: .event).filter { $0.allowsContentModifications }
    }

    private var currentCal: EKCalendar? {
        writableCalendars.first { $0.calendarIdentifier == selectedCalendarId } ?? store.defaultCalendarForNewEvents
    }

    private var currentCalColor: Color {
        if let c = currentCal { return Color(cgColor: c.cgColor) }
        return accentColor
    }

    private func shortName(_ name: String) -> String {
        name.contains("@") ? String(name.prefix(while: { $0 != "@" })) : name
    }

    private func field(_ icon: String, _ placeholder: String, _ text: Binding<String>, prefill: String?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(.white.opacity(0.25)).frame(width: 18)
            TextField(placeholder, text: text).textFieldStyle(.plain).font(.system(size: 13))
        }
    }

    // MARK: - Create

    private func createEvent() {
        guard !rawInput.isEmpty else { return }
        let ekEvent = EKEvent(eventStore: store)
        ekEvent.title = parsed.cleanTitle
        ekEvent.startDate = effectiveDate
        ekEvent.endDate = effectiveDate.addingTimeInterval(effectiveDuration)

        let loc = effectiveLocation
        if !loc.isEmpty { ekEvent.location = loc }

        var n = notes
        if !meetingLink.isEmpty { n = n.isEmpty ? meetingLink : "\(n)\n\(meetingLink)" }
        if !parsed.people.isEmpty {
            let ppl = "Attendees: " + parsed.people.joined(separator: ", ")
            n = n.isEmpty ? ppl : "\(n)\n\(ppl)"
        }
        if !n.isEmpty { ekEvent.notes = n }

        // Recurrence
        if let rec = parsed.recurrence {
            let freq: EKRecurrenceFrequency
            switch rec.lowercased() {
            case "daily": freq = .daily
            case "weekly": freq = .weekly
            case "monthly": freq = .monthly
            default:
                // "Every Monday" etc — weekly on that day
                freq = .weekly
            }
            ekEvent.addRecurrenceRule(EKRecurrenceRule(
                recurrenceWith: freq,
                interval: 1,
                end: nil
            ))
        }

        ekEvent.addAlarm(EKAlarm(relativeOffset: -300))
        ekEvent.calendar = currentCal ?? store.defaultCalendarForNewEvents

        do {
            try store.save(ekEvent, span: .thisEvent)
            appState.refreshEvents()
            isPresented = false
        } catch {}
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                                  proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
