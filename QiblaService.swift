import Foundation
import CoreLocation

/// Computes Qibla bearing using great-circle formula.
final class QiblaService {
    private let kaaba = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)

    func bearing(from location: CLLocationCoordinate2D) -> Double {
        let phi1 = location.latitude.radians
        let phi2 = kaaba.latitude.radians
        let deltaLambda = (kaaba.longitude - location.longitude).radians

        let y = sin(deltaLambda) * cos(phi2)
        let x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda)
        var theta = atan2(y, x).degrees
        if theta < 0 { theta += 360 }
        return theta
    }
}

private extension Double {
    var radians: Double { self * .pi / 180 }
    var degrees: Double { self * 180 / .pi }
}

