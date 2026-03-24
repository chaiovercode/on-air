import CoreLocation
import Foundation

@MainActor
final class SolarService: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var sunrise: Date?
    @Published var sunset: Date?

    private let locationManager = CLLocationManager()
    private var lastCoordinate: CLLocationCoordinate2D?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func refresh() {
        if let coord = lastCoordinate {
            calculate(for: coord)
        }
        locationManager.requestLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coord = location.coordinate
        Task { @MainActor in
            self.lastCoordinate = coord
            self.calculate(for: coord)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silently fail — sunrise/sunset just won't show
    }

    // MARK: - Solar calculation (simplified NOAA algorithm)

    private func calculate(for coord: CLLocationCoordinate2D) {
        let cal = Calendar.current
        let now = Date()
        let dayOfYear = Double(cal.ordinality(of: .day, in: .year, for: now) ?? 1)
        let lat = coord.latitude
        let lon = coord.longitude
        let tzOffset = Double(cal.timeZone.secondsFromGMT(for: now)) / 3600.0

        // Fractional year (radians)
        let gamma = 2.0 * .pi / 365.0 * (dayOfYear - 1.0)

        // Equation of time (minutes)
        let eqTime = 229.18 * (0.000075
            + 0.001868 * cos(gamma)
            - 0.032077 * sin(gamma)
            - 0.014615 * cos(2 * gamma)
            - 0.040849 * sin(2 * gamma))

        // Solar declination (radians)
        let decl = 0.006918
            - 0.399912 * cos(gamma)
            + 0.070257 * sin(gamma)
            - 0.006758 * cos(2 * gamma)
            + 0.000907 * sin(2 * gamma)
            - 0.002697 * cos(3 * gamma)
            + 0.00148 * sin(3 * gamma)

        let latRad = lat * .pi / 180.0
        let zenith = 90.833 * .pi / 180.0 // official sunrise/sunset zenith

        let cosHA = (cos(zenith) / (cos(latRad) * cos(decl))) - tan(latRad) * tan(decl)

        // Check for polar day/night
        guard cosHA >= -1 && cosHA <= 1 else { return }

        let ha = acos(cosHA) * 180.0 / .pi // hour angle in degrees

        // Sunrise and sunset in minutes from midnight UTC
        let sunriseMinutes = 720.0 - 4.0 * (lon + ha) - eqTime
        let sunsetMinutes = 720.0 - 4.0 * (lon - ha) - eqTime

        let startOfDay = cal.startOfDay(for: now)
        sunrise = startOfDay.addingTimeInterval((sunriseMinutes + tzOffset * 60) * 60)
        sunset = startOfDay.addingTimeInterval((sunsetMinutes + tzOffset * 60) * 60)
    }
}
