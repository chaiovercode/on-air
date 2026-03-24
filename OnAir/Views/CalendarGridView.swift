import SwiftUI
import EventKit

struct CalendarGridView: View {

    @ObservedObject var appState: AppState
    @Binding var displayedMonth: Date
    @Binding var selectedDate: Date?

    private let calendar = Calendar.current
    private let dayOfWeekHeaders = ["W", "M", "T", "W", "T", "F", "S"]
    private var accentRed: Color { Color(hex: appState.settings.accentColorHex) }
    @State private var eventCounts: [Date: Int] = [:]

    var body: some View {
        VStack(spacing: 10) {
            // Month header with navigation
            HStack {
                Text(monthYearString)
                    .font(.system(size: 14, weight: .bold))

                Spacer()

                HStack(spacing: 4) {
                    Button {
                        changeMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)

                    Button {
                        changeMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Day of week headers + week number column
            VStack(spacing: 4) {
                // Header row
                HStack(spacing: 0) {
                    // Week number column header
                    Text("")
                        .frame(width: 24)

                    ForEach(dayOfWeekHeaders, id: \.self) { header in
                        Text(header)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Calendar rows
                ForEach(calendarWeeks, id: \.self) { week in
                    HStack(spacing: 0) {
                        // Week number
                        Text("\(weekNumber(for: week.first ?? Date()))")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .frame(width: 24)

                        ForEach(week, id: \.self) { date in
                            dayCell(date: date)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .onAppear { loadEventCounts() }
        .onChange(of: displayedMonth) { _ in loadEventCounts() }
    }

    // MARK: - Day Cell

    @ViewBuilder
    private func dayCell(date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let isCurrentMonth = calendar.component(.month, from: date) == calendar.component(.month, from: displayedMonth)
        let isPast = date < calendar.startOfDay(for: Date()) && !isToday
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let dayStart = calendar.startOfDay(for: date)
        let count = eventCounts[dayStart] ?? 0
        let showHeatmap = appState.settings.showCalendarHeatmap && isCurrentMonth

        Button {
            selectedDate = date
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    // Heatmap background
                    if showHeatmap && count > 0 && !isToday {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(accentRed.opacity(heatmapOpacity(count: count)))
                            .frame(width: 28, height: 28)
                    }

                    if isToday {
                        Circle()
                            .fill(accentRed)
                            .frame(width: 26, height: 26)
                    } else if isSelected {
                        Circle()
                            .fill(.white.opacity(0.1))
                            .frame(width: 26, height: 26)
                    }

                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 13, weight: isCurrentMonth ? .semibold : .regular))
                        .foregroundColor(
                            isToday ? .white :
                            !isCurrentMonth ? .gray.opacity(0.3) :
                            isPast ? .gray : .primary
                        )
                }
                .frame(height: 28)

                // Event dot (when heatmap is off)
                if !showHeatmap {
                    Circle()
                        .fill(count > 0 ? Color.secondary : Color.clear)
                        .frame(width: 4, height: 4)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(height: showHeatmap ? 32 : 34)
    }

    private func heatmapOpacity(count: Int) -> Double {
        switch count {
        case 1: return 0.08
        case 2: return 0.15
        case 3: return 0.22
        case 4: return 0.30
        default: return min(0.40, 0.30 + Double(count - 4) * 0.03)
        }
    }

    // MARK: - Helpers

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            withAnimation(.easeInOut(duration: 0.2)) {
                displayedMonth = newDate
            }
        }
    }

    private func weekNumber(for date: Date) -> Int {
        calendar.component(.weekOfYear, from: date)
    }

    private func loadEventCounts() {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))!
        guard let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else { return }
        // Extend range to cover visible prev/next month days
        let start = calendar.date(byAdding: .day, value: -7, to: startOfMonth)!
        let end = calendar.date(byAdding: .day, value: 7, to: endOfMonth)!
        eventCounts = appState.calendarService.eventCounts(
            from: start,
            to: end,
            disabledCalendarIds: appState.settings.disabledCalendarIds
        )
    }

    private var calendarWeeks: [[Date]] {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))!

        // Find the Monday before or on the first day of the month
        var startDate = startOfMonth
        // Adjust to start from Monday (weekday 2)
        let weekday = calendar.component(.weekday, from: startDate)
        // weekday: 1=Sun, 2=Mon, ..., 7=Sat
        // We want to start from Monday
        let daysToSubtract = (weekday == 1) ? 6 : weekday - 2
        startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: startDate)!

        var weeks: [[Date]] = []
        var currentDate = startDate

        // Generate 6 weeks (covers all possible month layouts)
        for _ in 0..<6 {
            var week: [Date] = []
            for _ in 0..<7 {
                week.append(currentDate)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            weeks.append(week)
        }

        // Remove trailing week if all dates are in the next month
        if let lastWeek = weeks.last,
           let firstDayOfLastWeek = lastWeek.first,
           calendar.component(.month, from: firstDayOfLastWeek) != calendar.component(.month, from: displayedMonth) {
            weeks.removeLast()
        }

        return weeks
    }
}
