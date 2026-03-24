import SwiftUI

struct YearProgressView: View {

    var accentColor: Color = Color(red: 0.9, green: 0.25, blue: 0.2)

    private var progress: Double {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let endOfYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))!
        let totalDays = calendar.dateComponents([.day], from: startOfYear, to: endOfYear).day ?? 365
        let elapsedDays = calendar.dateComponents([.day], from: startOfYear, to: now).day ?? 0
        return Double(elapsedDays) / Double(totalDays)
    }

    private var daysLeft: Int {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let endOfYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))!
        return calendar.dateComponents([.day], from: now, to: endOfYear).day ?? 0
    }

    private var yearNumber: Int {
        Calendar.current.component(.year, from: Date())
    }

    var body: some View {
        VStack(spacing: 5) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.08))

                    // Filled portion
                    RoundedRectangle(cornerRadius: 3)
                        .fill(accentColor)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 6)

            // Labels
            HStack {
                Text(String(format: "%.1f%% of %d", progress * 100, yearNumber))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(daysLeft) days left")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
