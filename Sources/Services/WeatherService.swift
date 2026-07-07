import Foundation
import CoreLocation

// Keyless local weather: CoreLocation for coordinates + Open-Meteo's free current-conditions API.
@MainActor
@Observable
final class WeatherService: NSObject, CLLocationManagerDelegate {
    static let shared = WeatherService()

    private(set) var temperature: Int?
    private(set) var symbol: String = "thermometer.medium"
    private(set) var summary: String = "—"
    private(set) var locationName: String = ""
    private(set) var authorized = false

    private let manager = CLLocationManager()
    private var refreshTask: Task<Void, Never>?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func start() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = self.manager.authorizationStatus
            // On macOS a granted location request reports as .authorizedAlways (there is no
            // .authorizedWhenInUse case on macOS).
            authorized = status == .authorizedAlways
            if authorized { self.manager.startUpdatingLocation() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            self.manager.stopUpdatingLocation()
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            await reverseGeocode(location)
            await fetch(latitude: coordinate.latitude, longitude: coordinate.longitude)
            scheduleRefresh(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    private func scheduleRefresh(latitude: Double, longitude: Double) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(900))
                await self?.fetch(latitude: latitude, longitude: longitude)
            }
        }
    }

    private func reverseGeocode(_ location: CLLocation) async {
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
        if let city = placemarks?.first?.locality { locationName = city }
    }

    private func fetch(latitude: Double, longitude: Double) async {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "current", value: "temperature_2m,weather_code"),
            .init(name: "temperature_unit", value: "celsius")
        ]
        guard let url = components.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let decoded = try? JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        else { return }

        temperature = Int(decoded.current.temperature.rounded())
        let condition = WeatherCode.describe(decoded.current.code)
        symbol = condition.symbol
        summary = condition.label
    }
}

private struct CurrentWeather: Decodable {
    let temperature: Double
    let code: Int

    enum CodingKeys: String, CodingKey {
        case temperature = "temperature_2m"
        case code = "weather_code"
    }
}

private struct OpenMeteoResponse: Decodable {
    let current: CurrentWeather
}

private struct WeatherCondition {
    let symbol: String
    let label: String
}

private struct WeatherBand {
    let codes: Set<Int>
    let condition: WeatherCondition
}

private enum WeatherCode {
    // WMO weather-interpretation codes → SF Symbol + label, grouped by band.
    private static let bands: [WeatherBand] = [
        WeatherBand(codes: [0], condition: .init(symbol: "sun.max", label: "Clear")),
        WeatherBand(codes: [1, 2], condition: .init(symbol: "cloud.sun", label: "Partly cloudy")),
        WeatherBand(codes: [3], condition: .init(symbol: "cloud", label: "Overcast")),
        WeatherBand(codes: [45, 48], condition: .init(symbol: "cloud.fog", label: "Fog")),
        WeatherBand(codes: [51, 53, 55, 56, 57], condition: .init(symbol: "cloud.drizzle", label: "Drizzle")),
        WeatherBand(codes: [61, 63, 65, 66, 67], condition: .init(symbol: "cloud.rain", label: "Rain")),
        WeatherBand(codes: [71, 73, 75, 77], condition: .init(symbol: "cloud.snow", label: "Snow")),
        WeatherBand(codes: [80, 81, 82], condition: .init(symbol: "cloud.heavyrain", label: "Showers")),
        WeatherBand(codes: [85, 86], condition: .init(symbol: "cloud.snow", label: "Snow showers")),
        WeatherBand(codes: [95, 96, 99], condition: .init(symbol: "cloud.bolt.rain", label: "Thunderstorm"))
    ]

    static func describe(_ code: Int) -> WeatherCondition {
        bands.first { $0.codes.contains(code) }?.condition
            ?? WeatherCondition(symbol: "thermometer.medium", label: "—")
    }
}
