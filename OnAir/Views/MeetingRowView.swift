import SwiftUI

struct MeetingRowView: View {

    let event: CalendarEvent
    let isNext: Bool
    let isInProgress: Bool
    let isPast: Bool
    let accentRed: Color

    private var borderColor: Color {
        if isInProgress { return .green }
        if isNext { return accentRed }
        return .secondary.opacity(0.3)
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
        HStack(alignment: .top, spacing: 0) {
            // Colored left border (Dot-style)
            RoundedRectangle(cornerRadius: 2)
                .fill(borderColor)
                .frame(width: 3)
                .padding(.vertical, 2)

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
                        .font(.system(size: 14, weight: .medium))
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
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isInProgress ? .green.opacity(0.08) : isNext ? accentRed.opacity(0.06) : .clear)
        )
        .opacity(isPast ? 0.4 : 1.0)
        .padding(.vertical, 2)
    }

    private var timeRangeText: String {
        let start = event.startDate.formatted(date: .omitted, time: .shortened)
        let end = event.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }
}
