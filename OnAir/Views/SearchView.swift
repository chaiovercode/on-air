import SwiftUI

struct SearchView: View {

    @ObservedObject var appState: AppState
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @FocusState private var isFocused: Bool

    private let accentRed = Color(red: 0.9, green: 0.25, blue: 0.2)

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(accentRed)

                TextField("Search events...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($isFocused)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }

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
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Color.white.opacity(0.07).frame(height: 0.5)

            // Content
            if searchText.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(accentRed.opacity(0.08))
                            .frame(width: 60, height: 60)
                            .blur(radius: 15)

                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(.white.opacity(0.2))
                    }

                    Text("Search your calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))

                    Text("Find events by title, location, or notes")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.3))

                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 280)

            } else if results.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text("No results for \"\(searchText)\"")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 200)

            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(groupedResults, id: \.date) { group in
                            Text(dayLabel(group.date))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.4))
                                .tracking(1.2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.top, 10)

                            ForEach(group.events) { event in
                                searchResultRow(event)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 300)
            }

            // Footer — keyboard shortcuts
            Color.white.opacity(0.07).frame(height: 0.5)

            HStack(spacing: 16) {
                shortcutHint("ESC", label: "close")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .onAppear { isFocused = true }
        .onExitCommand { isPresented = false }
    }

    // MARK: - Components

    private func shortcutHint(_ key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(.white.opacity(0.06))
                )
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.25))
        }
    }

    private func searchResultRow(_ event: CalendarEvent) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: event.calendarColorHex))
                .frame(width: 3, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)

                Text("\(dayLabel(event.startDate)) · \(event.startDate.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.35))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Data

    private struct EventGroup: Identifiable {
        let date: Date
        let events: [CalendarEvent]
        var id: Date { date }
    }

    private var results: [CalendarEvent] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let endDate = calendar.date(byAdding: .month, value: 3, to: today) else { return [] }

        return appState.calendarService.fetchEvents(
            from: today,
            to: endDate,
            disabledCalendarIds: appState.settings.disabledCalendarIds
        ).filter {
            !$0.isAllDay &&
            ($0.title.lowercased().contains(query) ||
            ($0.location?.lowercased().contains(query) ?? false) ||
            ($0.notes?.lowercased().contains(query) ?? false))
        }
    }

    private var groupedResults: [EventGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: results) { event in
            calendar.startOfDay(for: event.startDate)
        }
        return grouped
            .map { EventGroup(date: $0.key, events: $0.value) }
            .filter { !$0.events.isEmpty }
            .sorted { $0.date < $1.date }
    }

    private func dayLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "TODAY" }
        if calendar.isDateInTomorrow(date) { return "TOMORROW" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMM"
        return formatter.string(from: date).uppercased()
    }
}
