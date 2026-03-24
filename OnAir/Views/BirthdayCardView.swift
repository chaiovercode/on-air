import SwiftUI

struct BirthdayCardView: View {

    @ObservedObject var appState: AppState

    private var accentColor: Color { Color(hex: appState.settings.accentColorHex) }

    var body: some View {
        if !birthdays.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(birthdays, id: \.event.id) { item in
                    HStack(spacing: 10) {
                        // Avatar circle with initial
                        let name = cleanName(item.event.title)
                        ZStack {
                            Circle()
                                .fill(Color(hex: item.event.calendarColorHex).opacity(0.15))
                                .frame(width: 28, height: 28)
                            Text(String(name.prefix(1)).uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(hex: item.event.calendarColorHex))
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(1)
                            Text(item.dayLabel)
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.3))
                        }

                        Spacer()

                        if item.isToday {
                            Text("today")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(accentColor.opacity(0.8))
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.white.opacity(0.04), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Data

    private struct BirthdayItem {
        let event: CalendarEvent
        let dayLabel: String
        let isToday: Bool
    }

    private var birthdays: [BirthdayItem] {
        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        guard let endDate = cal.date(byAdding: .day, value: 7, to: startOfToday) else { return [] }

        let allDayEvents = appState.calendarService.fetchAllDayEvents(
            from: startOfToday,
            to: endDate,
            disabledCalendarIds: appState.settings.disabledCalendarIds
        )

        // Filter to birthday-like events (from Birthdays calendar or title contains "birthday")
        let birthdayEvents = allDayEvents.filter { event in
            event.calendarTitle.lowercased().contains("birthday") ||
            event.title.lowercased().contains("birthday")
        }

        return birthdayEvents.prefix(5).map { event in
            let isToday = cal.isDateInToday(event.startDate)
            let label: String
            if isToday {
                label = "Today"
            } else if cal.isDateInTomorrow(event.startDate) {
                label = "Tomorrow"
            } else {
                let f = DateFormatter()
                f.dateFormat = "EEE"
                label = f.string(from: event.startDate)
            }
            return BirthdayItem(event: event, dayLabel: label, isToday: isToday)
        }
    }

    private func cleanName(_ title: String) -> String {
        var name = title
        // Strip common birthday suffixes
        let patterns = [
            #"'s \d+\w* Birthday"#,
            #"'s \d+\w*"#,
            #"'s Birthday"#,
            #"'s birthday"#,
            #" \d+\w* Birthday"#,
            #" Birthday"#,
            #" birthday"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                name = regex.stringByReplacingMatches(in: name, range: NSRange(name.startIndex..., in: name), withTemplate: "")
            }
        }
        return name.trimmingCharacters(in: .whitespaces)
    }
}
