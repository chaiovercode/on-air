import SwiftUI

struct StatsView: View {

    @ObservedObject var statsService: StatsService

    var body: some View {
        if statsService.records.isEmpty {
            emptyState
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    heroNumbers
                    busiestDays
                    platforms
                    peakHours
                    topMeetings
                }
                .padding(20)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.05))
                    .frame(width: 64, height: 64)
                Image(systemName: "chart.bar.xaxis.ascending")
                    .font(.system(size: 26))
                    .foregroundStyle(.secondary)
            }

            Text("No stats yet")
                .font(.system(size: 15, weight: .semibold))

            Text("Attend a meeting and your\nstats will appear here.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Hero Numbers

    private var heroNumbers: some View {
        HStack(spacing: 0) {
            heroStat(
                value: "\(statsService.meetingsThisWeek)",
                label: "this week",
                color: .red
            )
            heroStat(
                value: "\(statsService.meetingsThisMonth)",
                label: "this month",
                color: .blue
            )
            heroStat(
                value: statsService.totalHoursDisplay,
                label: "total time",
                color: .orange
            )
        }
    }

    private func heroStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(1.2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sections

    private var busiestDays: some View {
        chartSection(title: "Busiest Days", icon: "calendar") {
            VStack(spacing: 6) {
                ForEach(statsService.busiestDays.prefix(5), id: \.dayOfWeek) { day in
                    chartBar(
                        label: String(day.dayOfWeek.prefix(3)),
                        percentage: day.percentage,
                        color: .red
                    )
                }
            }
        }
    }

    private var platforms: some View {
        chartSection(title: "Platforms", icon: "video.fill") {
            VStack(spacing: 6) {
                ForEach(statsService.platformBreakdown, id: \.platform) { item in
                    chartBar(
                        label: item.platform,
                        percentage: item.percentage,
                        color: .blue
                    )
                }
            }
        }
    }

    private var peakHours: some View {
        chartSection(title: "Peak Hours", icon: "clock.fill") {
            VStack(spacing: 6) {
                ForEach(statsService.peakHours.prefix(4), id: \.hour) { item in
                    chartBar(
                        label: item.hour,
                        percentage: item.percentage,
                        color: .orange
                    )
                }
            }
        }
    }

    private var topMeetings: some View {
        chartSection(title: "Recurring", icon: "arrow.2.squarepath") {
            VStack(spacing: 8) {
                ForEach(Array(statsService.topMeetings.enumerated()), id: \.element.title) { index, item in
                    HStack(spacing: 10) {
                        Text("#\(index + 1)")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .frame(width: 20)

                        Text(item.title)
                            .font(.system(size: 12))
                            .lineLimit(1)

                        Spacer()

                        Text("\(item.count)×")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Shared Components

    private func chartSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
            } icon: {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(.secondary)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chartBar(label: String, percentage: Double, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 65, alignment: .leading)
                .lineLimit(1)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.06))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.8), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * percentage / 100, 6))
                }
            }
            .frame(height: 8)

            Text("\(Int(percentage))%")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
                .monospacedDigit()
        }
    }
}
