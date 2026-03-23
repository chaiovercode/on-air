import SwiftUI
import EventKit

struct NewEventView: View {

    @ObservedObject var appState: AppState
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var selectedDate = Date()
    @State private var duration: TimeInterval = 3600
    @State private var isAllDay = false
    @FocusState private var isFocused: Bool

    private let accentRed = Color(red: 0.9, green: 0.25, blue: 0.2)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("New Event")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Text("ESC")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.white.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
            }

            // Title input
            TextField("Event title", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .medium))
                .focused($isFocused)

            Divider()

            // Date picker
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .controlSize(.small)
            }

            // Duration
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Picker("", selection: $duration) {
                    Text("15 min").tag(TimeInterval(900))
                    Text("30 min").tag(TimeInterval(1800))
                    Text("45 min").tag(TimeInterval(2700))
                    Text("1 hour").tag(TimeInterval(3600))
                    Text("1.5 hours").tag(TimeInterval(5400))
                    Text("2 hours").tag(TimeInterval(7200))
                }
                .pickerStyle(.menu)
                .controlSize(.small)

                Toggle("All day", isOn: $isAllDay)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .controlSize(.small)
            }

            Divider()

            // Create button
            HStack {
                Spacer()
                Button {
                    createEvent()
                } label: {
                    Text("Create ⌘⏎")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(accentRed, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(title.isEmpty)
                .opacity(title.isEmpty ? 0.5 : 1)
            }
        }
        .padding(16)
        .frame(width: 320)
        .onAppear { isFocused = true }
        .onExitCommand { isPresented = false }
    }

    private func createEvent() {
        guard !title.isEmpty else { return }

        let store = EKEventStore()
        let ekEvent = EKEvent(eventStore: store)
        ekEvent.title = title
        ekEvent.startDate = selectedDate
        ekEvent.endDate = isAllDay ? selectedDate : selectedDate.addingTimeInterval(duration)
        ekEvent.isAllDay = isAllDay
        ekEvent.calendar = store.defaultCalendarForNewEvents

        do {
            try store.save(ekEvent, span: .thisEvent)
            appState.refreshEvents()
            isPresented = false
        } catch {
            // Silent fail
        }
    }
}
