import SwiftUI

struct SunArcView: View {

    let sunrise: Date?
    let sunset: Date?
    var accentColor: Color = .orange
    var use24Hour: Bool = false

    private let arcHeight: CGFloat = 32

    var body: some View {
        if let sunrise, let sunset {
            VStack(spacing: 4) {
                // Arc with sun position
                GeometryReader { geo in
                    let w = geo.size.width
                    let progress = sunProgress(sunrise: sunrise, sunset: sunset)

                    ZStack {
                        // Horizon line
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: arcHeight))
                            p.addLine(to: CGPoint(x: w, y: arcHeight))
                        }
                        .stroke(.white.opacity(0.06), lineWidth: 0.5)

                        // Daylight arc
                        Path { p in
                            for i in 0...Int(w) {
                                let x = CGFloat(i)
                                let t = x / w
                                let y = arcHeight - sin(t * .pi) * arcHeight
                                if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                                else { p.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(
                            LinearGradient(
                                colors: [.orange.opacity(0.15), .yellow.opacity(0.3), .orange.opacity(0.15)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )

                        // Filled area below arc (subtle)
                        Path { p in
                            for i in 0...Int(w) {
                                let x = CGFloat(i)
                                let t = x / w
                                let y = arcHeight - sin(t * .pi) * arcHeight
                                if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                                else { p.addLine(to: CGPoint(x: x, y: y)) }
                            }
                            p.addLine(to: CGPoint(x: w, y: arcHeight))
                            p.addLine(to: CGPoint(x: 0, y: arcHeight))
                            p.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [.orange.opacity(0.03), .yellow.opacity(0.06), .orange.opacity(0.03)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                        // Night arc (below horizon, subtle)
                        if progress < 0 || progress > 1 {
                            Path { p in
                                for i in 0...Int(w) {
                                    let x = CGFloat(i)
                                    let t = x / w
                                    let y = arcHeight + sin(t * .pi) * (arcHeight * 0.5)
                                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                                    else { p.addLine(to: CGPoint(x: x, y: y)) }
                                }
                            }
                            .stroke(.indigo.opacity(0.15), lineWidth: 1)
                        }

                        // Sun/Moon dot
                        let sunPos = sunPosition(progress: progress, width: w, arcH: arcHeight)

                        Circle()
                            .fill(isDay ? .yellow.opacity(0.2) : .indigo.opacity(0.15))
                            .frame(width: 16, height: 16)
                            .position(x: sunPos.x, y: sunPos.y)

                        Circle()
                            .fill(isDay ? .yellow : .white.opacity(0.5))
                            .frame(width: 6, height: 6)
                            .position(x: sunPos.x, y: sunPos.y)
                    }
                }
                .frame(height: arcHeight + arcHeight * 0.5 + 6)

                // Labels
                HStack {
                    HStack(spacing: 3) {
                        Text("↑")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange.opacity(0.5))
                        Text(formatTime(sunrise))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.35))
                    }

                    Spacer()

                    if let daylight = daylightText(sunrise: sunrise, sunset: sunset) {
                        Text(daylight)
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.2))
                    }

                    Spacer()

                    HStack(spacing: 3) {
                        Text(formatTime(sunset))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.35))
                        Text("↓")
                            .font(.system(size: 9))
                            .foregroundStyle(.indigo.opacity(0.5))
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var isDay: Bool {
        guard let sunrise, let sunset else { return true }
        let now = Date()
        return now >= sunrise && now <= sunset
    }

    private func sunPosition(progress: CGFloat, width: CGFloat, arcH: CGFloat) -> CGPoint {
        guard let sunrise, let sunset else {
            return CGPoint(x: width / 2, y: arcH)
        }

        let now = Date()

        if now >= sunrise && now <= sunset {
            // Daytime — arc above horizon, left to right
            let t = CGFloat(now.timeIntervalSince(sunrise) / sunset.timeIntervalSince(sunrise))
            let x = t * width
            let y = arcH - sin(t * .pi) * arcH
            return CGPoint(x: x, y: y)
        } else {
            // Nighttime — arc below horizon, right (sunset) to left (sunrise)
            let dayLength = sunset.timeIntervalSince(sunrise)
            let nightLength = 86400 - dayLength // 24h - daylight

            let nightElapsed: TimeInterval
            if now > sunset {
                nightElapsed = now.timeIntervalSince(sunset)
            } else {
                // Before sunrise — night started at previous sunset
                nightElapsed = nightLength - sunrise.timeIntervalSince(now)
            }

            let t = CGFloat(min(max(nightElapsed / nightLength, 0), 1))
            // Night goes right to left: x = 1-t
            let x = (1 - t) * width
            let y = arcH + sin(t * .pi) * (arcH * 0.5)
            return CGPoint(x: x, y: y)
        }
    }

    private func sunProgress(sunrise: Date, sunset: Date) -> CGFloat {
        let now = Date()
        let total = sunset.timeIntervalSince(sunrise)
        guard total > 0 else { return 0.5 }
        let elapsed = now.timeIntervalSince(sunrise)
        return CGFloat(elapsed / total)
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = use24Hour ? "HH:mm" : "h:mma"
        let s = f.string(from: date).lowercased()
        return use24Hour ? s : String(s.dropLast(1)) // drop trailing 'm' from 'am/pm' → 'a/p'
    }

    private func daylightText(sunrise: Date, sunset: Date) -> String? {
        let mins = Int(sunset.timeIntervalSince(sunrise) / 60)
        guard mins > 0 else { return nil }
        let h = mins / 60
        let m = mins % 60
        return "\(h)h \(m)m daylight"
    }
}
