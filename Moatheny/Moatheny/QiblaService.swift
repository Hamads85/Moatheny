import Foundation
import CoreLocation

/// Handles Qibla direction retrieval with API integration, caching, and local calculation fallback.
final class QiblaService {
    // MARK: - Dependencies
    private let api: APIClient
    private let cache: LocalCache
    
    // إحداثيات الكعبة المشرفة الدقيقة (مركز الكعبة)
    // موحدة مع QiblaCalculator و API aladhan.com
    // المصدر: Google Qibla Finder و aladhan.com
    private let kaaba = CLLocationCoordinate2D(latitude: 21.4224779, longitude: 39.8251832)
    
    // MARK: - Cache Configuration
    /// مدة صلاحية الكاش بالثواني (24 ساعة)
    private let cacheValidityDuration: TimeInterval = 24 * 60 * 60
    
    /// دقة الإحداثيات للكاش (بالدرجات)
    /// كل 0.01 درجة ≈ 1.1 كيلومتر
    /// هذا يعني أن الإحداثيات التي تختلف بأقل من 0.01 درجة ستستخدم نفس الكاش
    private let coordinatePrecision: Double = 0.01
    
    // MARK: - Initialization
    
    init(api: APIClient, cache: LocalCache) {
        self.api = api
        self.cache = cache
    }
    
    // MARK: - Public Methods
    
    // MARK: - Models
    enum Source: String {
        case api
        case cache
        case gpsFallback
    }
    
    struct QiblaResult {
        let bearing: Double
        let distance: Double
        let source: Source
        let isStale: Bool
    }
    
    /// جلب اتجاه القبلة مع دعم API أولاً + Cache + GPS fallback
    func fetchQibla(for location: CLLocationCoordinate2D) async -> QiblaResult {
        let distanceToKaaba = distance(from: location)
        
        // 1) كاش حديث
        if let cached = loadCachedDirection(for: location) {
            return QiblaResult(bearing: cached.direction, distance: distanceToKaaba, source: cached.fromCache ? .cache : .api, isStale: cached.isStale)
        }
        
        // 2) API أساسي
        do {
            let direction = try await withTimeout(seconds: 5) { [self] in
                try await self.api.fetchQiblaDirection(latitude: location.latitude, longitude: location.longitude)
            }
            saveCachedDirection(direction, for: location, fromCache: false)
            return QiblaResult(bearing: direction, distance: distanceToKaaba, source: .api, isStale: false)
        } catch {
            print("⚠️ فشل جلب اتجاه القبلة من API: \(error.localizedDescription)")
            let localDirection = calculateLocalBearing(from: location)
            saveCachedDirection(localDirection, for: location, fromCache: true)
            return QiblaResult(bearing: localDirection, distance: distanceToKaaba, source: .gpsFallback, isStale: false)
        }
    }
    
    /// متوافق مع الواجهات القديمة (bearing فقط)
    func bearing(from location: CLLocationCoordinate2D) async throws -> Double {
        let result = await fetchQibla(for: location)
        return result.bearing
    }
    
    /// حساب اتجاه القبلة محلياً (للـ fallback)
    /// النتيجة: زاوية من 0-360 درجة حيث 0° = شمال، 90° = شرق، 180° = جنوب، 270° = غرب
    func calculateLocalBearing(from location: CLLocationCoordinate2D) -> Double {
        // تحويل إلى راديان
        let lat1 = location.latitude.radians
        let lon1 = location.longitude.radians
        let lat2 = kaaba.latitude.radians
        let lon2 = kaaba.longitude.radians
        
        // حساب الفرق في خطوط الطول
        let dLon = lon2 - lon1
        
        // صيغة Great Circle Bearing
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        var bearing = atan2(y, x).degrees
        
        // تحويل من -180/+180 إلى 0-360
        if bearing < 0 {
            bearing += 360
        }
        
        return bearing
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
    
    // MARK: - Caching
    
    /// إنشاء مفتاح الكاش بناءً على الإحداثيات
    private func cacheKey(for location: CLLocationCoordinate2D) -> String {
        // تقريب الإحداثيات لتجميع المواقع القريبة
        let roundedLat = round(location.latitude / coordinatePrecision) * coordinatePrecision
        let roundedLon = round(location.longitude / coordinatePrecision) * coordinatePrecision
        return "qibla_\(String(format: "%.4f", roundedLat))_\(String(format: "%.4f", roundedLon)).json"
    }
    
    /// نموذج البيانات المحفوظة في الكاش
    private struct CachedQiblaData: Codable {
        let direction: Double
        let latitude: Double
        let longitude: Double
        let timestamp: TimeInterval
        let fromCache: Bool
    }
    
    /// تحميل اتجاه القبلة من الكاش
    private func loadCachedDirection(for location: CLLocationCoordinate2D) -> (direction: Double, fromCache: Bool, isStale: Bool)? {
        let key = cacheKey(for: location)
        
        guard let cached: CachedQiblaData = try? cache.load(CachedQiblaData.self, named: key) else {
            return nil
        }
        
        // التحقق من صلاحية الكاش
        let age = Date().timeIntervalSince1970 - cached.timestamp
        let isStale = age >= cacheValidityDuration
        if isStale {
            try? FileManager.default.removeItem(atPath: FilePaths.cached(key).path)
            return nil
        }
        
        // التحقق من أن الإحداثيات متطابقة (مع هامش خطأ صغير)
        let latDiff = abs(cached.latitude - location.latitude)
        let lonDiff = abs(cached.longitude - location.longitude)
        guard latDiff < coordinatePrecision && lonDiff < coordinatePrecision else {
            return nil
        }
        
        return (cached.direction, cached.fromCache, isStale)
    }
    
    /// حفظ اتجاه القبلة في الكاش
    private func saveCachedDirection(_ direction: Double, for location: CLLocationCoordinate2D, fromCache: Bool) {
        let key = cacheKey(for: location)
        let data = CachedQiblaData(
            direction: direction,
            latitude: location.latitude,
            longitude: location.longitude,
            timestamp: Date().timeIntervalSince1970,
            fromCache: fromCache
        )
        
        try? cache.store(data, named: key)
    }
    
    /// Helper function للـ timeout
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw AppError.network("Qibla API timeout")
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

private extension Double {
    var radians: Double { self * .pi / 180 }
    var degrees: Double { self * 180 / .pi }
}

