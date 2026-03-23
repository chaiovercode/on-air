import SwiftUI

struct StatsView: View {

    @ObservedObject var statsService: StatsService

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                summaryCard
                if !statsService.records.isEmpty {
                    busiestDaysCard
                    platformsCard
                    peakHoursCard
                    topMeetingsCard
                }
            }
            .padding(16)
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(spacing: 8) {
            if statsService.records.isEmpty {
                Text("No meetings tracked yet")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                HStack(spacing: 16) {
                    statItem(value: "\(statsService.meetingsThisWeek)", label: "This Week")
                    Divider().frame(height: 30)
                    statItem(value: "\(statsService.meetingsThisMonth)", label: "This Month")
                    Divider().frame(height: 30)
                    statItem(value: statsService.totalHoursDisplay, label: "Total Hours")
                }
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .glassEffect(.regular.interactive())
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Busiest Days

    private var busiestDaysCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BUSIEST DAYS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(1)

            ForEach(statsService.busiestDays.prefix(5), id: \.dayOfWeek) { day in
                barRow(label: day.dayOfWeek, percentage: day.percentage, count: day.count)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassEffect(.regular.interactive())
    }

    // MARK: - Platforms

    private var platformsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PLATFORMS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(1)

            ForEach(statsService.platformBreakdown, id: \.platform) { item in
                barRow(label: item.platform, percentage: item.percentage, count: item.count)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassEffect(.regular.interactive())
    }

    // MARK: - Peak Hours

    private var peakHoursCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PEAK HOURS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(1)

            ForEach(statsService.peakHours.prefix(5), id: \.hour) { item in
                barRow(label: item.hour, percentage: item.percentage, count: item.count)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassEffect(.regular.interactive())
    }

    // MARK: - Top Meetings

    private var topMeetingsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TOP MEETINGS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(1)

            ForEach(statsService.topMeetings, id: \.title) { item in
                HStack {
                    Text(item.title)
                        .font(.system(size: 12))
                        .lineLimit(1)
                    Spacer()
                    Text("\(item.count)x")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassEffect(.regular.interactive())
    }

    // MARK: - Bar Row Helper

    private func barRow(label: String, percentage: Double, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.accentColor.opacity(0.7))
                    .frame(width: max(geo.size.width * percentage / 100, 4))
            }
            .frame(height: 14)

            Text("\(Int(percentage))%")
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}
