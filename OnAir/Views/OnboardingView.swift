import SwiftUI

struct OnboardingView: View {

    let onComplete: () -> Void
    @State private var step = 0
    @State private var calendarGranted = false
    @State private var animateIn = false
    @State private var dotScale: CGFloat = 0.6
    @State private var glowOpacity: Double = 0.0

    private let accentRed = Color(red: 0.9, green: 0.25, blue: 0.2)

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.09, green: 0.08, blue: 0.07)

            // Warm gradient
            VStack {
                RadialGradient(
                    colors: [accentRed.opacity(0.08), .clear],
                    center: .top,
                    startRadius: 20,
                    endRadius: 300
                )
                .frame(height: 300)
                Spacer()
            }

            // Content
            VStack(spacing: 0) {
                Spacer()

                switch step {
                case 0: welcomeStep
                case 1: calendarStep
                default: doneStep
                }

                Spacer()

                // Step dots
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(i == step ? accentRed : Color.white.opacity(0.15))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .frame(width: 440, height: 520)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { animateIn = true }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                dotScale = 1.0
                glowOpacity = 1.0
            }
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            // Animated "on air" dot
            ZStack {
                Circle()
                    .fill(accentRed.opacity(0.12 * glowOpacity))
                    .frame(width: 120, height: 120)
                    .scaleEffect(dotScale)

                Circle()
                    .fill(accentRed.opacity(0.25 * glowOpacity))
                    .frame(width: 72, height: 72)
                    .scaleEffect(dotScale)

                Circle()
                    .fill(accentRed)
                    .frame(width: 36, height: 36)

                Circle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 10, height: 10)
                    .offset(x: -6, y: -6)
            }
            .padding(.bottom, 8)

            VStack(spacing: 10) {
                Text("OnAir")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)

                Text("Your meetings, always visible.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Text("A minimal menu bar companion that\nkeeps you ahead of your schedule.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer().frame(height: 16)

            actionButton("Get Started") {
                withAnimation(.easeInOut(duration: 0.3)) { step = 1 }
            }
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
    }

    // MARK: - Step 2: Calendar Access

    private var calendarStep: some View {
        VStack(spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 88, height: 88)

                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(accentRed)
            }
            .padding(.bottom, 4)

            VStack(spacing: 10) {
                Text("Calendar Access")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text("OnAir reads your calendar to show\nupcoming meetings in the menu bar.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            // Feature list
            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "bell.badge", text: "Countdown alerts before meetings")
                featureRow(icon: "eye", text: "See your next event at a glance")
                featureRow(icon: "lock.shield", text: "Events stay on your device")
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 16)

            Spacer().frame(height: 8)

            if calendarGranted {
                actionButton("Continue") {
                    withAnimation(.easeInOut(duration: 0.3)) { step = 2 }
                }
            } else {
                actionButton("Grant Access") {
                    Task {
                        let granted = await requestCalendarAccess()
                        calendarGranted = granted
                        if granted {
                            withAnimation(.easeInOut(duration: 0.3)) { step = 2 }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step 3: Done

    private var doneStep: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 88, height: 88)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.green.opacity(0.8))
            }
            .padding(.bottom, 4)

            VStack(spacing: 10) {
                Text("You're all set")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text("OnAir lives in your menu bar.\nClick the dot to see your schedule.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            // Menu bar hint
            HStack(spacing: 10) {
                Circle()
                    .fill(accentRed)
                    .frame(width: 8, height: 8)
                Text("Team Standup in 12m")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            )

            Spacer().frame(height: 16)

            actionButton("Start Using OnAir") {
                onComplete()
            }
        }
    }

    // MARK: - Components

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(accentRed.opacity(0.7))
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 200, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accentRed)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Calendar

    private func requestCalendarAccess() async -> Bool {
        let store = EKEventStore()
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }
}

import EventKit
