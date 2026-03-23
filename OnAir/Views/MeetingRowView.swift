import SwiftUI

struct MeetingRowView: View {

    let event: CalendarEvent
    let isNext: Bool
    let isInProgress: Bool
    let isPast: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Live indicator
            statusIndicator

            // Meeting info
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.system(size: 13, weight: isNext || isInProgress ? .semibold : .medium))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(event.startDate.formatted(date: .omitted, time: .shortened))

                    Text("·")

                    Text(event.durationDisplay)

                    if let link = event.meetingLink {
                        Text("·")
                        Text(link.platform.displayName)
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            // Action
            if isInProgress {
                liveBadge
            } else if let link = event.meetingLink {
                Button {
                    NSWorkspace.shared.open(link.url)
                } label: {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(.blue, in: Circle())
                }
                .buttonStyle(.plain)
                .help("Join \(link.platform.displayName)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            if isNext || isInProgress {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isNext ? .red.opacity(0.12) : .green.opacity(0.1))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .opacity(isPast ? 0.4 : 1.0)
    }

    // MARK: - Components

    @ViewBuilder
    private var statusIndicator: some View {
        if isInProgress {
            // Pulsing green dot
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(.green.opacity(0.4), lineWidth: 2)
                        .scaleEffect(1.6)
                )
        } else if isNext {
            // Red dot — next up
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
        } else {
            // Subtle ring
            Circle()
                .stroke(.quaternary, lineWidth: 1.5)
                .frame(width: 8, height: 8)
        }
    }

    private var liveBadge: some View {
        Text("LIVE")
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .tracking(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.green, in: Capsule())
    }
}
