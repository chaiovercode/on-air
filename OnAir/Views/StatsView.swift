import SwiftUI

struct StatsView: View {

    @ObservedObject var statsService: StatsService

    private let accent = Color(red: 0.9, green: 0.25, blue: 0.2)
    private let cardFill = Color.white.opacity(0.035)
    private let cardBorder = Color.white.opacity(0.055)

    var body: some View {
        if statsService.records.isEmpty {
            emptyState
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    // Hero row — 3 stat cards
                    heroRow

                    // Two-column layout
                    HStack(alignment: .top, spacing: 10) {
                        // Left column
                        VStack(spacing: 10) {
                            busiestDays
                            peakHours
                        }
                        // Right column
                        VStack(spacing: 10) {
                            platforms
                            topMeetings
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                // Glow
                Circle()
                    .fill(accent.opacity(0.08))
                    .frame(width: 100, height: 100)
                    .blur(radius: 25)

                // Icon ring
                Circle()
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    .frame(width: 72, height: 72)

                Image(systemName: "chart.bar.xaxis.ascending")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.3))
            }

            VStack(spacing: 6) {
                Text("No stats yet")
                    .font(.system(size: 16, weight: .semibold))

                Text("Attend a meeting and your\nstats will appear here.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Hero Stats

    private var heroRow: some View {
        HStack(spacing: 10) {
            heroCard(
                value: "\(statsService.meetingsThisWeek)",
                label: "THIS WEEK",
                icon: "flame.fill",
                color: accent
            )
            heroCard(
                value: "\(statsService.meetingsThisMonth)",
                label: "THIS MONTH",
                icon: "calendar",
                color: Color(red: 0.35, green: 0.55, blue: 1.0)
            )
            heroCard(
                value: statsService.totalHoursDisplay,
                label: "TOTAL TIME",
                icon: "clock.fill",
                color: Color(red: 1.0, green: 0.6, blue: 0.2)
            )
        }
    }

    private func heroCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack {
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(color.opacity(0.5))
            }

            Text(value)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)

            Text(label)
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(Color.white.opacity(0.3))
                .tracking(1.5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cardFill)

                // Subtle color tint at top
                VStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.06), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 40)
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(cardBorder, lineWidth: 0.5)
        )
    }

    // MARK: - Busiest Days

    private var busiestDays: some View {
        sectionCard(title: "BUSIEST DAYS", icon: "calendar") {
            VStack(spacing: 5) {
                ForEach(statsService.busiestDays.prefix(5), id: \.dayOfWeek) { day in
                    statBar(
                        label: String(day.dayOfWeek.prefix(3)),
                        value: day.percentage,
                        color: accent
                    )
                }
            }
        }
    }

    // MARK: - Platforms

    private var platforms: some View {
        sectionCard(title: "PLATFORMS", icon: "video.fill") {
            VStack(spacing: 5) {
                ForEach(statsService.platformBreakdown, id: \.platform) { item in
                    statBar(
                        label: item.platform,
                        value: item.percentage,
                        color: Color(red: 0.35, green: 0.55, blue: 1.0)
                    )
                }
            }
        }
    }

    // MARK: - Peak Hours

    private var peakHours: some View {
        sectionCard(title: "PEAK HOURS", icon: "clock.fill") {
            VStack(spacing: 5) {
                ForEach(statsService.peakHours.prefix(4), id: \.hour) { item in
                    statBar(
                        label: item.hour,
                        value: item.percentage,
                        color: Color(red: 1.0, green: 0.6, blue: 0.2)
                    )
                }
            }
        }
    }

    // MARK: - Top Meetings

    private var topMeetings: some View {
        sectionCard(title: "RECURRING", icon: "arrow.2.squarepath") {
            VStack(spacing: 0) {
                ForEach(Array(statsService.topMeetings.enumerated()), id: \.element.title) { index, item in
                    HStack(spacing: 10) {
                        // Rank badge
                        Text("\(index + 1)")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundStyle(index == 0 ? accent : Color.white.opacity(0.25))
                            .frame(width: 18, height: 18)
                            .background(
                                Circle()
                                    .fill(index == 0 ? accent.opacity(0.15) : Color.white.opacity(0.04))
                            )

                        Text(item.title)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .lineLimit(1)

                        Spacer()

                        Text("\(item.count)×")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.35))
                            .monospacedDigit()
                    }
                    .padding(.vertical, 6)

                    if index < statsService.topMeetings.count - 1 {
                        Color.white.opacity(0.04).frame(height: 0.5)
                    }
                }
            }
        }
    }

    // MARK: - Reusable Components

    private func sectionCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.3))
                Text(title)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .tracking(1.2)
            }

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(cardBorder, lineWidth: 0.5)
        )
    }

    private func statBar(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.55))
                .frame(width: 55, alignment: .leading)
                .lineLimit(1)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.white.opacity(0.04))

                    // Fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.6), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * value / 100, 4))
                        .shadow(color: color.opacity(0.3), radius: 4, x: 2)
                }
            }
            .frame(height: 6)

            Text("\(Int(value))%")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.3))
                .frame(width: 26, alignment: .trailing)
                .monospacedDigit()
        }
    }
}
