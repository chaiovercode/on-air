import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            red: Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8) & 0xFF) / 255,
            blue: Double(int & 0xFF) / 255
        )
    }
}

struct MeetingRowView: View {

    let event: CalendarEvent
    let isNext: Bool
    let isInProgress: Bool
    let isPast: Bool
    let accentRed: Color

    @State private var showDetail = false

    private var borderColor: Color {
        Color(hex: event.calendarColorHex)
    }

    private var timeBadgeText: String? {
        let now = Date()
        if isInProgress {
            let remaining = Int(event.endDate.timeIntervalSince(now) / 60)
            return "\(remaining)m left"
        } else if event.startDate > now {
            let until = Int(event.startDate.timeIntervalSince(now) / 60)
            if until <= 60 {
                return "in \(until)m"
            }
        }
        return nil
    }

    private var timeBadgeColor: Color {
        if isInProgress { return .green }
        return accentRed
    }

    var body: some View {
        Button {
            showDetail = true
        } label: {
            HStack(alignment: .top, spacing: 0) {
                // Colored left border — green gradient for in-progress
                if isInProgress {
                    let total = event.endDate.timeIntervalSince(event.startDate)
                    let elapsed = Date().timeIntervalSince(event.startDate)
                    let progress = min(max(elapsed / total, 0), 1)

                    GeometryReader { geo in
                        VStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.green)
                                .frame(height: geo.size.height * progress)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.green.opacity(0.2))
                                .frame(height: geo.size.height * (1 - progress))
                        }
                    }
                    .frame(width: 3)
                    .padding(.vertical, 2)
                } else {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(borderColor)
                        .frame(width: 3)
                        .padding(.vertical, 2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    // Time range row
                    HStack {
                        Text(timeRangeText)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)

                        Spacer()

                        // Time badge
                        if let badge = timeBadgeText {
                            Text(badge)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(timeBadgeColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(timeBadgeColor.opacity(0.15))
                                )
                        }
                    }

                    // Title row
                    HStack(spacing: 8) {
                        Text(event.title)
                            .font(.system(size: 15, weight: .medium))
                            .lineLimit(1)

                        Spacer()

                        if let link = event.meetingLink {
                            Button {
                                NSWorkspace.shared.open(link.url)
                            } label: {
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .frame(width: 22, height: 22)
                                    .background(
                                        Circle().fill(.white.opacity(0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                            .help("Join \(link.platform.displayName)")
                        }
                    }

                    // Platform badge
                    if let link = event.meetingLink {
                        Text(link.platform.displayName)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.leading, 10)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(
                GeometryReader { geo in
                    if isInProgress {
                        let total = event.endDate.timeIntervalSince(event.startDate)
                        let elapsed = Date().timeIntervalSince(event.startDate)
                        let progress = min(max(elapsed / total, 0), 1)

                        ZStack(alignment: .leading) {
                            // Base
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.green.opacity(0.04))

                            // Green progress fill
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.green.opacity(0.20), Color.green.opacity(0.10)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progress)
                        }
                    } else if isNext {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(accentRed.opacity(0.06))
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                // Green border for in-progress
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isInProgress ? Color.green.opacity(0.35) : .clear, lineWidth: 0.5)
            )
            .opacity(isPast ? 0.4 : 1.0)
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showDetail) {
            EventDetailView(event: event, onDismiss: { showDetail = false })
        }
    }

    private var timeRangeText: String {
        let start = event.startDate.formatted(date: .omitted, time: .shortened)
        let end = event.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }
}
