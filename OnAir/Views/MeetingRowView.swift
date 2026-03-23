import SwiftUI

struct MeetingRowView: View {

    let event: CalendarEvent
    let isNext: Bool
    let isInProgress: Bool
    let isPast: Bool

    private var dotColor: Color {
        if isInProgress { return .green }
        if isNext { return .red }
        return .clear
    }

    private var dotBorder: Color {
        if !isNext && !isInProgress { return .secondary }
        return .clear
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(dotColor)
                .overlay(Circle().stroke(dotBorder, lineWidth: 1.5))
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(event.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    Spacer()

                    if let link = event.meetingLink {
                        Button("Join") {
                            NSWorkspace.shared.open(link.url)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(.blue)
                    }
                }

                HStack(spacing: 6) {
                    Text(event.startDate.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text("·")
                        .foregroundColor(.secondary)

                    Text(event.durationDisplay)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    if let link = event.meetingLink {
                        Text(link.platform.displayName)
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(3)
                    } else {
                        Text("No link")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.6))
                            .italic()
                    }

                    if isInProgress {
                        Text("In progress")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isNext ? Color.red.opacity(0.08) : Color.clear)
        .opacity(isPast ? 0.5 : 1.0)
        .glassEffect(.regular.interactive())
    }
}
