import SwiftUI
import EventKit

struct EventDetailView: View {

    let event: CalendarEvent
    let onDismiss: () -> Void

    private let accentRed = Color(red: 0.9, green: 0.25, blue: 0.2)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(event.title)
                .font(.system(size: 16, weight: .bold))

            // Calendar
            HStack(spacing: 6) {
                Circle()
                    .fill(.purple)
                    .frame(width: 8, height: 8)
                Text(event.calendarTitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            // Date & time
            VStack(alignment: .leading, spacing: 2) {
                Text(event.startDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.system(size: 12))

                HStack {
                    Text("\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Text("· \(event.durationDisplay)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Time badge
                    if let badge = timeBadge {
                        Text(badge)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isInProgress ? .green : accentRed)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(isInProgress ? .green.opacity(0.15) : accentRed.opacity(0.15))
                            )
                    }
                }
            }

            // Meeting link
            if let link = event.meetingLink {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(link.platform.displayName)
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                }
            }

            // Location
            if let location = event.location, !location.isEmpty, event.meetingLink == nil {
                HStack(spacing: 6) {
                    Image(systemName: "mappin")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(location)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Divider()

            // Action buttons
            HStack(spacing: 8) {
                actionButton(icon: "pencil", label: "Edit") {
                    // Open in Calendar.app
                    if let url = URL(string: "x-apple-calevent://\(event.id)") {
                        NSWorkspace.shared.open(url)
                    }
                }

                if let link = event.meetingLink {
                    actionButton(icon: "video", label: "Join") {
                        NSWorkspace.shared.open(link.url)
                    }
                }

                actionButton(icon: "doc.on.doc", label: "Copy") {
                    let text = "\(event.title)\n\(event.startDate.formatted()) – \(event.endDate.formatted())"
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }

                Spacer()
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThickMaterial)
        )
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    private var isInProgress: Bool {
        event.startDate <= Date() && event.endDate > Date()
    }

    private var timeBadge: String? {
        let now = Date()
        if isInProgress {
            let mins = Int(event.endDate.timeIntervalSince(now) / 60)
            return "\(mins)m left"
        } else if event.startDate > now {
            let mins = Int(event.startDate.timeIntervalSince(now) / 60)
            if mins <= 60 { return "in \(mins)m" }
        }
        return nil
    }
}
