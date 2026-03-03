import Foundation
import CoreLocation

/// حاسبة اتجاه القبلة - استخدام Great Circle Bearing
/// 
/// بسيطة، دقيقة، وواضحة
struct QiblaCalculator {
    /// إحداثيات الكعبة المشرفة (مركز الكعبة)
    static let kaabaLatitude: Double = 21.4224779
    static let kaabaLongitude: Double = 39.8251832
    
    /// حساب اتجاه القبلة من موقع معين باستخدام Great Circle Bearing
    /// 
    /// الخوارزمية:
    /// - تستخدم معادلة Bearing Formula لحساب الزاوية الأولية
    /// - بين الموقع الحالي والكعبة على سطح الكرة الأرضية
    ///
    /// - Parameters:
    ///   - latitude: خط العرض للموقع الحالي (بالدرجات، -90 إلى +90)
    ///   - longitude: خط الطول للموقع الحالي (بالدرجات، -180 إلى +180)
    /// - Returns: اتجاه القبلة بالدرجات (0-360، حيث 0 = الشمال)
    /// - Note: يستخدم نظام إحداثيات WGS84
    static func calculateQiblaDirection(from latitude: Double, longitude: Double) -> Double {
        // التحقق من صحة الإحداثيات
        guard abs(latitude) <= 90 && abs(longitude) <= 180 else {
            print("⚠️ إحداثيات غير صالحة: lat=\(latitude), lon=\(longitude)")
            return 0
        }
        // تحويل الإحداثيات من درجات إلى راديان
        let lat1 = latitude * .pi / 180.0
        let lon1 = longitude * .pi / 180.0
        let lat2 = kaabaLatitude * .pi / 180.0
        let lon2 = kaabaLongitude * .pi / 180.0
        
        // حساب فرق خطوط الطول
        let deltaLon = lon2 - lon1
        
        // تطبيق معادلة Great Circle Bearing
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        // حساب الزاوية وتحويلها إلى درجات
        var bearing = atan2(y, x) * 180.0 / .pi
        
        // تطبيع الزاوية إلى النطاق [0, 360)
        bearing = (bearing + 360.0).truncatingRemainder(dividingBy: 360.0)
        
        return bearing
    }
    
    /// حساب المسافة إلى الكعبة بالكيلومترات
    /// 
    /// - Parameters:
    ///   - latitude: خط العرض للموقع الحالي (بالدرجات)
    ///   - longitude: خط الطول للموقع الحالي (بالدرجات)
    /// - Returns: المسافة بالكيلومترات
    static func calculateDistanceToKaaba(from latitude: Double, longitude: Double) -> Double {
        let earthRadius = 6371.0 // كيلومتر
        
        // تحويل الإحداثيات من درجات إلى راديان
        let lat1 = latitude * .pi / 180.0
        let lon1 = longitude * .pi / 180.0
        let lat2 = kaabaLatitude * .pi / 180.0
        let lon2 = kaabaLongitude * .pi / 180.0
        
        // حساب فروق الإحداثيات
        let deltaLat = lat2 - lat1
        let deltaLon = lon2 - lon1
        
        // تطبيق معادلة Haversine
        let a = sin(deltaLat / 2.0) * sin(deltaLat / 2.0) +
                cos(lat1) * cos(lat2) *
                sin(deltaLon / 2.0) * sin(deltaLon / 2.0)
        
        let c = 2.0 * atan2(sqrt(a), sqrt(1.0 - a))
        
        return earthRadius * c
    }
    
    /// حساب زاوية دوران السهم للإشارة إلى القبلة
    /// 
    /// المنطق:
    /// - السهم يشير للأعلى في البداية (0°)
    /// - نحتاج تدويره ليشير لاتجاه القبلة
    /// - إذا الجهاز موجه للشمال (heading=0) والقبلة في 243°
    ///   → السهم يجب أن يدور 243° في اتجاه عقارب الساعة
    /// - إذا الجهاز موجه للقبلة (heading=243°) والقبلة في 243°
    ///   → السهم يجب أن يشير للأعلى (rotation=0)
    ///
    /// الصيغة: rotation = qiblaDirection - deviceHeading
    ///
    /// - Parameters:
    ///   - qiblaDirection: اتجاه القبلة (0-360)
    ///   - deviceHeading: اتجاه الجهاز الحالي (0-360)
    /// - Returns: زاوية دوران السهم بالدرجات
    static func calculateArrowRotation(qiblaDirection: Double, deviceHeading: Double) -> Double {
        // التحقق من القيم غير الصالحة
        guard qiblaDirection.isFinite && deviceHeading.isFinite else {
            return 0
        }
        
        // الصيغة الصحيحة: qiblaDirection - deviceHeading
        var rotation = qiblaDirection - deviceHeading
        
        // تطبيع إلى [-180, 180] لاختيار أقصر مسار للدوران
        rotation = (rotation + 180).truncatingRemainder(dividingBy: 360) - 180
        
        return rotation
    }
    
    /// وصف الاتجاه بالعربية
    static func directionName(for bearing: Double) -> String {
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
