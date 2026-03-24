import SwiftUI

struct FocusTimerView: View {

    @ObservedObject var appState: AppState

    private var focus: FocusService { appState.focusService }
    private var accentColor: Color { Color(hex: appState.settings.accentColorHex) }

    @State private var selectedMinutes: Int = 25
    @State private var editingLabel = false

    private let presets = [15, 25, 45, 60]

    var body: some View {
        VStack(spacing: 0) {
            if focus.isRunning {
                activeSession
            } else {
                idleState
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
        )
        .onAppear {
            let nextIn = appState.secondsUntilNext > 0 ? appState.secondsUntilNext : nil
            let suggested = focus.suggestedDuration(nextEventIn: nextIn)
            selectedMinutes = suggested / 60
        }
    }

    // MARK: - Idle State

    private var idleState: some View {
        VStack(spacing: 10) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(accentColor.opacity(0.7))
                Text("Focus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                if focus.todayFocusMinutes > 0 {
                    Text("\(focus.todayFocusMinutes)m today")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.25))
                }
            }

            // Duration pills
            HStack(spacing: 6) {
                ForEach(presets, id: \.self) { mins in
                    Button {
                        selectedMinutes = mins
                    } label: {
                        Text("\(mins)m")
                            .font(.system(size: 11, weight: selectedMinutes == mins ? .bold : .regular))
                            .foregroundStyle(selectedMinutes == mins ? .white : .white.opacity(0.35))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(selectedMinutes == mins ? accentColor.opacity(0.25) : .white.opacity(0.04))
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            // Smart suggestion
            if let suggestion = smartSuggestion {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                        .foregroundStyle(accentColor.opacity(0.5))
                    Text(suggestion)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Start button
            Button {
                focus.start(duration: selectedMinutes * 60, label: focus.sessionLabel)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9))
                    Text("Start Focus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accentColor.opacity(0.8))
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Active Session

    private var activeSession: some View {
        VStack(spacing: 10) {
            // Header with label
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(accentColor.opacity(0.7))
                Text(focus.sessionLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Button { focus.stop() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }

            // Timer display
            HStack(spacing: 14) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.06), lineWidth: 3)
                        .frame(width: 44, height: 44)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                    if focus.isPaused {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(accentColor)
                    }
                }

                // Time remaining
                VStack(alignment: .leading, spacing: 2) {
                    Text(timeString)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("remaining")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.3))
                }

                Spacer()

                // Pause/Resume
                Button {
                    if focus.isPaused { focus.resume() } else { focus.pause() }
                } label: {
                    Image(systemName: focus.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle().fill(accentColor.opacity(0.3))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private var progress: Double {
        guard focus.totalSeconds > 0 else { return 0 }
        return 1 - Double(focus.secondsRemaining) / Double(focus.totalSeconds)
    }

    private var timeString: String {
        let m = focus.secondsRemaining / 60
        let s = focus.secondsRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var smartSuggestion: String? {
        let nextIn = appState.secondsUntilNext
        guard nextIn > 0 else { return nil }
        let mins = nextIn / 60
        if mins <= 65 {
            return "\(mins)m until your next meeting"
        }
        return nil
    }
}
