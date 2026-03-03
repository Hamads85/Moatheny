import Foundation
import CoreLocation

/// سكريبت التحقق من دقة حساب اتجاه القبلة
/// يقارن الحساب المحلي مع API aladhan.com

struct QiblaAccuracyValidation {
    
    // إحداثيات الكعبة من API
    static let kaabaAPI = CLLocationCoordinate2D(
        latitude: 21.4224779,
        longitude: 39.8251832
    )
    
    // إحداثيات الكعبة من QiblaService (باب الكعبة)
    static let kaabaQiblaService = CLLocationCoordinate2D(
        latitude: 21.422487,
        longitude: 39.826206
    )
    
    /// حساب اتجاه القبلة باستخدام Great Circle Bearing
    static func calculateBearing(
        from location: CLLocationCoordinate2D,
        to kaaba: CLLocationCoordinate2D
    ) -> Double {
        // تحويل إلى راديان
        let lat1 = location.latitude * .pi / 180.0
        let lon1 = location.longitude * .pi / 180.0
        let lat2 = kaaba.latitude * .pi / 180.0
        let lon2 = kaaba.longitude * .pi / 180.0
        
        // حساب فرق خطوط الطول
        let deltaLon = lon2 - lon1
        
        // صيغة Great Circle Bearing
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        var bearing = atan2(y, x) * 180.0 / .pi
        
        // تطبيع إلى [0, 360]
        if bearing < 0 {
            bearing += 360.0
        }
        
        return bearing
    }
    
    /// التحقق من دقة الحساب للرياض
    static func validateRiyadh() {
        print("=" * 60)
        print("التحقق من دقة حساب اتجاه القبلة - الرياض")
        print("=" * 60)
        print()
        
        let riyadh = CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753)
        let apiResult = 243.79818967345182
        
        print("📍 موقع الاختبار: الرياض")
        print("   خط العرض: \(riyadh.latitude)°N")
        print("   خط الطول: \(riyadh.longitude)°E")
        print()
        
        print("🕋 إحداثيات الكعبة:")
        print("   API: \(kaabaAPI.latitude)°N, \(kaabaAPI.longitude)°E")
        print("   QiblaService: \(kaabaQiblaService.latitude)°N, \(kaabaQiblaService.longitude)°E")
        print()
        
        // حساب مع إحداثيات API
        let bearingWithAPI = calculateBearing(from: riyadh, to: kaabaAPI)
        let diffWithAPI = abs(bearingWithAPI - apiResult)
        
        // حساب مع إحداثيات QiblaService
        let bearingWithQiblaService = calculateBearing(from: riyadh, to: kaabaQiblaService)
        let diffWithQiblaService = abs(bearingWithQiblaService - apiResult)
        
        print("📊 النتائج:")
        print("   API aladhan.com:        \(String(format: "%.6f", apiResult))°")
        print("   الحساب المحلي (API):   \(String(format: "%.6f", bearingWithAPI))°")
        print("   الحساب المحلي (Service): \(String(format: "%.6f", bearingWithQiblaService))°")
        print()
        
        print("📏 الفروقات:")
        print("   الفرق مع API:          \(String(format: "%.6f", diffWithAPI))°")
        print("   الفرق مع QiblaService: \(String(format: "%.6f", diffWithQiblaService))°")
        print()
        
        // التحقق من الدقة
        let tolerance = 0.5 // درجة واحدة
        let isAccurateWithAPI = diffWithAPI < tolerance
        let isAccurateWithService = diffWithQiblaService < tolerance
        
        print("✅ التحقق من الدقة (هامش خطأ: ±\(tolerance)°):")
        print("   مع إحداثيات API:       \(isAccurateWithAPI ? "✅ دقيق" : "❌ غير دقيق")")
        print("   مع إحداثيات Service:   \(isAccurateWithService ? "✅ دقيق" : "❌ غير دقيق")")
        print()
        
        // التحليل
        print("📝 التحليل:")
        if diffWithAPI < 0.1 {
            print("   ✅ الفرق مع API صغير جداً (< 0.1°) - دقة ممتازة")
        } else if diffWithAPI < 0.5 {
            print("   ✅ الفرق مع API صغير (< 0.5°) - دقة عالية")
        } else if diffWithAPI < 1.0 {
            print("   ⚠️ الفرق مع API متوسط (< 1.0°) - دقة مقبولة")
        } else {
            print("   ❌ الفرق مع API كبير (> 1.0°) - يحتاج مراجعة")
        }
        
        print()
        print("=" * 60)
    }
    
    /// اختبار مواقع متعددة
    static func validateMultipleLocations() {
        print("=" * 60)
        print("التحقق من دقة حساب اتجاه القبلة - مواقع متعددة")
        print("=" * 60)
        print()
        
        struct TestLocation {
            let name: String
            let coordinate: CLLocationCoordinate2D
            let expectedBearing: Double? // من API إن وجد
        }
        
        let locations: [TestLocation] = [
            TestLocation(name: "الرياض", coordinate: CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753), expectedBearing: 243.798),
            TestLocation(name: "جدة", coordinate: CLLocationCoordinate2D(latitude: 21.4858, longitude: 39.1925), expectedBearing: nil),
            TestLocation(name: "القاهرة", coordinate: CLLocationCoordinate2D(latitude: 30.0444, longitude: 31.2357), expectedBearing: nil),
            TestLocation(name: "دبي", coordinate: CLLocationCoordinate2D(latitude: 25.2048, longitude: 55.2708), expectedBearing: nil),
        ]
        
        for location in locations {
            let bearing = calculateBearing(from: location.coordinate, to: kaabaAPI)
            
            print("📍 \(location.name):")
            print("   الإحداثيات: \(location.coordinate.latitude)°N, \(location.coordinate.longitude)°E")
            print("   الاتجاه المحسوب: \(String(format: "%.2f", bearing))°")
            
            if let expected = location.expectedBearing {
                let diff = abs(bearing - expected)
                print("   الاتجاه المتوقع (API): \(String(format: "%.2f", expected))°")
                print("   الفرق: \(String(format: "%.3f", diff))°")
                print("   الحالة: \(diff < 0.5 ? "✅ دقيق" : "⚠️ يحتاج مراجعة")")
            }
            
            print()
        }
        
        print("=" * 60)
    }
}

// Extension لسهولة الطباعة
extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}

// تشغيل التحقق
if CommandLine.arguments.contains("--validate") {
    QiblaAccuracyValidation.validateRiyadh()
    print()
    QiblaAccuracyValidation.validateMultipleLocations()
}
