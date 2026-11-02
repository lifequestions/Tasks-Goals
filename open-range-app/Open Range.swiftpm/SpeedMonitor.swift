import CoreLocation
import Foundation

/// Reads the phone's GPS speed so the rider can compare it with the Cowboy app.
final class SpeedMonitor: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var kmh: Double?
    @Published private(set) var topKmh: Double = 0
    @Published private(set) var denied = false

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .fitness
    }

    func start() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
    }

    func stop() { manager.stopUpdatingLocation() }

    func resetTop() { topKmh = 0 }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        denied = manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
        if !denied { manager.startUpdatingLocation() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        // A negative speed or accuracy means the GPS doesn't have a reading yet.
        guard location.speed >= 0, location.speedAccuracy >= 0 else { kmh = nil; return }
        let value = location.speed * 3.6
        kmh = value
        if value > topKmh { topKmh = value }
    }
}
