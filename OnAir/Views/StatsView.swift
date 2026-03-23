import SwiftUI

struct StatsView: View {

    @ObservedObject var statsService: StatsService

    var body: some View {
        ScrollView {
            if statsService.records.isEmpty {
                emptyState
            } else {
                VStack(spacing: 16) {
                    summaryRow
                    busiestDaysCard
                    platformsCard
                    peakHoursCard
                    topMeetingsCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)

            Text("No stats yet")
                .font(.system(size: 14, weight: .semibold))

            Text("Stats appear as you attend meetings")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    // MARK: - Summary

    private var summaryRow: some View {
        HStack(spacing: 0) {
            statPill(value: "\(statsService.meetingsThisWeek)", label: "week")
            statPill(value: "\(statsService.meetingsThisMonth)", label: "month")
            statPill(value: statsService.totalHoursDisplay, label: "total")
        }
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Cards

    private var busiestDaysCard: some View {
        statsCard(title: "Busiest Days", icon: "calendar") {
            ForEach(statsService.busiestDays.prefix(5), id: \.dayOfWeek) { day in
                barRow(label: String(day.dayOfWeek.prefix(3)), value: day.percentage, color: .red)
            }
        }
    }

    private var platformsCard: some View {
        statsCard(title: "Platforms", icon: "video") {
            ForEach(statsService.platformBreakdown, id: \.platform) { item in
                barRow(label: item.platform, value: item.percentage, color: .blue)
            }
        }
    }

    private var peakHoursCard: some View {
        statsCard(title: "Peak Hours", icon: "clock") {
            ForEach(statsService.peakHours.prefix(4), id: \.hour) { item in
                barRow(label: item.hour, value: item.percentage, color: .orange)
            }
        }
    }

    private var topMeetingsCard: some View {
        statsCard(title: "Recurring", icon: "repeat") {
            ForEach(statsService.topMeetings, id: \.title) { item in
                HStack {
                    Text(item.title)
                        .font(.system(size: 11))
                        .lineLimit(1)
                    Spacer()
                    Text("\(item.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Shared Components

    private func statsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func barRow(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .frame(width: 72, alignment: .leading)
                .lineLimit(1)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.quaternary)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.7))
                        .frame(width: max(geo.size.width * value / 100, 3))
                }
            }
            .frame(height: 10)

            Text("\(Int(value))%")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
                .monospacedDigit()
        }
    }
}
