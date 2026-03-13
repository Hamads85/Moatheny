import Foundation
import CoreLocation
import Adhan

/// Handles Qibla direction retrieval using high-precision local calculation (Adhan library).
final class QiblaService {
    // MARK: - Dependencies
    private let cache: LocalCache
    
    // إحداثيات الكعبة المشرفة الدقيقة (مركز الكعبة)
    private let kaaba = CLLocationCoordinate2D(latitude: 21.4224779, longitude: 39.8251832)
    
    // MARK: - Initialization
    
    init(cache: LocalCache) {
        self.cache = cache
    }
    
    // MARK: - Models
    enum Source: String {
        case api
        case cache
        case gpsFallback
        case localCalculation // New source type for Adhan lib
    }
    
    struct QiblaResult {
        let bearing: Double
        let distance: Double
        let source: Source
        let isStale: Bool
    }
    
    /// جلب اتجاه القبلة باستخدام حسابات محلية دقيقة (Adhan Library)
    /// هذا يضمن دقة 100% بناءً على الإحداثيات ودعم العمل بدون إنترنت
    func fetchQibla(for location: CLLocationCoordinate2D) async -> QiblaResult {
        let distanceToKaaba = distance(from: location)
        
        // استخدام مكتبة Adhan للحساب الدقيق (Great Circle Bearing)
        let coordinates = Coordinates(latitude: location.latitude, longitude: location.longitude)
        let qibla = Qibla(coordinates: coordinates)
        let direction = qibla.direction
        
        return QiblaResult(bearing: direction, distance: distanceToKaaba, source: .localCalculation, isStale: false)
    }
    
    /// متوافق مع الواجهات القديمة (bearing فقط)
    func bearing(from location: CLLocationCoordinate2D) async throws -> Double {
        let result = await fetchQibla(for: location)
        return result.bearing
    }
    
    /// حساب المسافة بالكيلومتر من موقع المستخدم إلى الكعبة
    func distance(from location: CLLocationCoordinate2D) -> Double {
        let userLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let kaabaLocation = CLLocation(latitude: kaaba.latitude, longitude: kaaba.longitude)
        return userLocation.distance(from: kaabaLocation) / 1000 // بالكيلومتر
    }
    
    /// وصف الاتجاه بالعربية
    func directionName(for bearing: Double) -> String {
        switch bearing {
        case 0..<22.5: return "شمال"
        case 22.5..<67.5: return "شمال شرق"
        case 67.5..<112.5: return "شرق"
        case 112.5..<157.5: return "جنوب شرق"
        case 157.5..<202.5: return "جنوب"
        case 202.5..<247.5: return "جنوب غرب"
        case 247.5..<292.5: return "غرب"
        case 292.5..<337.5: return "شمال غرب"
        default: return "شمال"
        }
    }
}
