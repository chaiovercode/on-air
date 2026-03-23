import SwiftUI

struct StatsView: View {

    @ObservedObject var statsService: StatsService

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                summaryCard
                if !statsService.records.isEmpty {
                    busiestDaysCard
                    platformsCard
                    peakHoursCard
                    topMeetingsCard
                }
            }
            .padding(12)
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(spacing: 8) {
            if statsService.records.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("No meetings tracked yet")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("Stats will appear as you attend meetings")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 24)
            } else {
                HStack(spacing: 0) {
                    statItem(value: "\(statsService.meetingsThisWeek)", label: "This Week")
                    Divider().frame(height: 30)
                    statItem(value: "\(statsService.meetingsThisMonth)", label: "This Month")
                    Divider().frame(height: 30)
                    statItem(value: statsService.totalHoursDisplay, label: "Total Hours")
                }
                .padding(.vertical, 10)
            }
        }
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Cards

    private var busiestDaysCard: some View {
        statsCard(title: "BUSIEST DAYS") {
            ForEach(statsService.busiestDays.prefix(5), id: \.dayOfWeek) { day in
                barRow(label: day.dayOfWeek, percentage: day.percentage)
            }
        }
    }

    private var platformsCard: some View {
        statsCard(title: "PLATFORMS") {
            ForEach(statsService.platformBreakdown, id: \.platform) { item in
                barRow(label: item.platform, percentage: item.percentage)
            }
        }
    }

    private var peakHoursCard: some View {
        statsCard(title: "PEAK HOURS") {
            ForEach(statsService.peakHours.prefix(5), id: \.hour) { item in
                barRow(label: item.hour, percentage: item.percentage)
            }
        }
    }

    private var topMeetingsCard: some View {
        statsCard(title: "TOP MEETINGS") {
            ForEach(statsService.topMeetings, id: \.title) { item in
                HStack {
                    Text(item.title)
                        .font(.system(size: 12))
                        .lineLimit(1)
                    Spacer()
                    Text("\(item.count)x")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func statsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
    }

    private func barRow(label: String, percentage: Double) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(.tint.opacity(0.6))
                    .frame(width: max(geo.size.width * percentage / 100, 4))
            }
            .frame(height: 14)

            Text("\(Int(percentage))%")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}
