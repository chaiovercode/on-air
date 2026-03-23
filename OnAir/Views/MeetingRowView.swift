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
        if !isNext && !isInProgress { return .secondary.opacity(0.5) }
        return .clear
    }

    private var rowBackground: some ShapeStyle {
        if isNext { return AnyShapeStyle(.red.opacity(0.1)) }
        if isInProgress { return AnyShapeStyle(.green.opacity(0.08)) }
        return AnyShapeStyle(.clear)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Status dot
            Circle()
                .fill(dotColor)
                .overlay(Circle().stroke(dotBorder, lineWidth: 1.5))
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
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
                        .controlSize(.mini)
                        .tint(.accentColor)
                    }
                }

                HStack(spacing: 5) {
                    Text(event.startDate.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Text(event.durationDisplay)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    if let link = event.meetingLink {
                        Text(link.platform.displayName)
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    } else {
                        Text("No link")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .italic()
                    }

                    if isInProgress {
                        Text("In progress")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isNext ? Color.red.opacity(0.1) : isInProgress ? Color.green.opacity(0.08) : Color.white.opacity(0.05))
        )
        .opacity(isPast ? 0.5 : 1.0)
    }
}
