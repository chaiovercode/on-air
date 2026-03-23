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
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(accentRed)

                TextField("Search events...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($isFocused)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    isPresented = false
                } label: {
                    Text("ESC")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.white.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(12)

            Divider()

            // Results
            if searchText.isEmpty {
                VStack {
                    Spacer()
                    Text("Type to search events")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxHeight: 200)
            } else if results.isEmpty {
                VStack {
                    Spacer()
                    Text("No results for \"\(searchText)\"")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxHeight: 200)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        // Group by day
                        ForEach(groupedResults, id: \.date) { group in
                            Text(dayLabel(group.date))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                                .tracking(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.top, 8)

                            ForEach(group.events) { event in
                                searchResultRow(event)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 300)

                Divider()

                // Footer
                HStack {
                    Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                        .font(.system(size: 10))
                        .foregroundStyle(accentRed)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
        .onAppear { isFocused = true }
        .onExitCommand { isPresented = false }
    }

    private func searchResultRow(_ event: CalendarEvent) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(.purple)
                .frame(width: 3, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Text("\(dayLabel(event.startDate)) · \(event.startDate.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10))
                    .foregroundStyle(accentRed)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
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
        ).filter { $0.title.lowercased().contains(query) }
    }

    private var groupedResults: [EventGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: results) { event in
            calendar.startOfDay(for: event.startDate)
        }
        return grouped
            .map { EventGroup(date: $0.key, events: $0.value) }
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
