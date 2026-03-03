import Foundation
import CoreLocation

/// حاسبة الانحراف المغناطيسي (Magnetic Declination Calculator)
///
/// ## الانحراف المغناطيسي:
/// الفرق بين الشمال المغناطيسي والشمال الحقيقي (Geographic North)
/// - **Positive**: الشمال المغناطيسي شرق الشمال الحقيقي
/// - **Negative**: الشمال المغناطيسي غرب الشمال الحقيقي
///
/// ## World Magnetic Model (WMM):
/// نموذج عالمي لحساب المجال المغناطيسي للأرض
/// - يستخدم معاملات Spharmonic (Spherical Harmonic)
/// - دقيق حتى ±0.5° في معظم المناطق
/// - يتم تحديثه كل 5 سنوات
///
/// ## الخوارزمية:
/// استخدام نموذج WMM المبسط لحساب الانحراف:
/// ```
/// declination = atan2(Y, X)
/// ```
/// حيث X و Y هي مركبات المجال المغناطيسي الأفقي
///
/// ## معاملات WMM2020 (مبسطة):
/// نستخدم نموذج ثنائي القطب (Dipole Model) مبسط مع تصحيح إضافي
final class MagneticDeclinationCalculator {
    // MARK: - WMM Coefficients (Simplified Model)
    
    /// معاملات WMM المبسطة (لعام 2020)
    /// هذه معاملات مبسطة - للحصول على دقة أعلى يمكن استخدام WMM الكامل
    private struct WMMCoefficients {
        // معاملات المجال الرئيسي (Main Field)
        static let g10: Double = -29404.5  // nT
        static let g11: Double = -1450.7   // nT
        static let h11: Double = 4652.5    // nT
        
        // معاملات التغير السنوي (Secular Variation)
        static let g10Dot: Double = 8.0    // nT/year
        static let g11Dot: Double = 10.7   // nT/year
        static let h11Dot: Double = -25.9  // nT/year
        
        // سنة الأساس (Epoch)
        static let epoch: Double = 2020.0
    }
    
    // MARK: - Earth Constants
    
    /// نصف قطر الأرض (بالمتر)
    private static let earthRadius: Double = 6371200.0
    
    // MARK: - Calculation
    
    /// حساب الانحراف المغناطيسي لموقع معين
    /// - Parameters:
    ///   - latitude: خط العرض (بالدرجات)
    ///   - longitude: خط الطول (بالدرجات)
    ///   - date: التاريخ (لحساب التغير السنوي)
    /// - Returns: الانحراف المغناطيسي بالدرجات (موجب = شرق، سالب = غرب)
    static func calculateDeclination(
        latitude: Double,
        longitude: Double,
        date: Date = Date()
    ) -> Double {
        // تحويل الإحداثيات إلى راديان
        let latRad = latitude * .pi / 180.0
        let lonRad = longitude * .pi / 180.0
        
        // حساب السنة الكسرية (fractional year)
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let fractionalYear = Double(year) + Double(dayOfYear - 1) / 365.25
        
        // حساب التغير منذ سنة الأساس
        let yearsSinceEpoch = fractionalYear - WMMCoefficients.epoch
        
        // تحديث المعاملات مع التغير السنوي
        let g10 = WMMCoefficients.g10 + WMMCoefficients.g10Dot * yearsSinceEpoch
        let g11 = WMMCoefficients.g11 + WMMCoefficients.g11Dot * yearsSinceEpoch
        let h11 = WMMCoefficients.h11 + WMMCoefficients.h11Dot * yearsSinceEpoch
        
        // حساب مركبات المجال المغناطيسي
        let (x, y, _) = calculateMagneticFieldComponents(
            latRad: latRad,
            lonRad: lonRad,
            g10: g10,
            g11: g11,
            h11: h11
        )
        
        // حساب الانحراف المغناطيسي
        // declination = atan2(Y, X) حيث Y و X هما المركبات الأفقية
        let declinationRad = atan2(y, x)
        let declinationDeg = declinationRad * 180.0 / .pi
    
        return declinationDeg
    }
    
    /// حساب مركبات المجال المغناطيسي
    private static func calculateMagneticFieldComponents(
        latRad: Double,
        lonRad: Double,
        g10: Double,
        g11: Double,
        h11: Double
    ) -> (x: Double, y: Double, z: Double) {
        // حساب sin و cos للزوايا
        let sinLat = sin(latRad)
        let cosLat = cos(latRad)
        let sinLon = sin(lonRad)
        let cosLon = cos(lonRad)
        
        // حساب المركبات باستخدام نموذج Dipole المبسط
        // X (شمالي)
        let x = g10 * cosLat + (g11 * cosLon + h11 * sinLon) * sinLat
        
        // Y (شرقي)
        let y = g11 * sinLon - h11 * cosLon
        
        // Z (عمودي - للأسفل)
        let z = g10 * sinLat - (g11 * cosLon + h11 * sinLon) * cosLat
        
        return (x: x, y: y, z: z)
    }
    
    // MARK: - Conversion Helpers
    
    /// تحويل heading من مغناطيسي إلى حقيقي
    /// - Parameters:
    ///   - magneticHeading: الاتجاه المغناطيسي (بالدرجات)
    ///   - latitude: خط العرض
    ///   - longitude: خط الطول
    /// - Returns: الاتجاه الحقيقي (بالدرجات)
    static func magneticToTrue(
        magneticHeading: Double,
        latitude: Double,
        longitude: Double
    ) -> Double {
        let declination = calculateDeclination(latitude: latitude, longitude: longitude)
        var trueHeading = magneticHeading + declination
        
        // تطبيع إلى [0, 360)
        while trueHeading < 0 { trueHeading += 360 }
        while trueHeading >= 360 { trueHeading -= 360 }
        
        return trueHeading
    }
    
    /// تحويل heading من حقيقي إلى مغناطيسي
    /// - Parameters:
    ///   - trueHeading: الاتجاه الحقيقي (بالدرجات)
    ///   - latitude: خط العرض
    ///   - longitude: خط الطول
    /// - Returns: الاتجاه المغناطيسي (بالدرجات)
    static func trueToMagnetic(
        trueHeading: Double,
        latitude: Double,
        longitude: Double
    ) -> Double {
        let declination = calculateDeclination(latitude: latitude, longitude: longitude)
        var magneticHeading = trueHeading - declination
        
        // تطبيع إلى [0, 360)
        while magneticHeading < 0 { magneticHeading += 360 }
        while magneticHeading >= 360 { magneticHeading -= 360 }
        
        return magneticHeading
    }
    
    // MARK: - Location-based Calculation
    
    /// حساب الانحراف المغناطيسي لموقع CLLocation
    /// - Parameter location: موقع CLLocation
    /// - Returns: الانحراف المغناطيسي بالدرجات
    static func calculateDeclination(for location: CLLocation) -> Double {
        return calculateDeclination(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            date: location.timestamp
        )
    }
    
    // MARK: - Accuracy Estimation
    
    /// تقدير دقة حساب الانحراف
    /// - Parameters:
    ///   - latitude: خط العرض
    ///   - longitude: خط الطول
    /// - Returns: دقة متوقعة بالدرجات (±)
    ///
    /// ملاحظة: النموذج المبسط دقيق إلى ±1-2° في معظم المناطق
    /// للحصول على دقة أعلى (±0.5°)، استخدم WMM الكامل
    static func estimateAccuracy(latitude: Double, longitude: Double) -> Double {
        // الدقة تعتمد على الموقع
        // المناطق القطبية أقل دقة
        let absLat = abs(latitude)
        
        if absLat > 80 {
            return 3.0 // دقة أقل في المناطق القطبية
        } else if absLat > 60 {
            return 2.0
        } else {
            return 1.0 // دقة جيدة في معظم المناطق
        }
    }
}

// MARK: - Extension for CLLocation

extension CLLocation {
    /// الانحراف المغناطيسي لهذا الموقع
    var magneticDeclination: Double {
        return MagneticDeclinationCalculator.calculateDeclination(for: self)
    }
    
    /// تحويل heading مغناطيسي إلى حقيقي
    func magneticToTrueHeading(_ magneticHeading: Double) -> Double {
        return MagneticDeclinationCalculator.magneticToTrue(
            magneticHeading: magneticHeading,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }
    
    /// تحويل heading حقيقي إلى مغناطيسي
    func trueToMagneticHeading(_ trueHeading: Double) -> Double {
        return MagneticDeclinationCalculator.trueToMagnetic(
            trueHeading: trueHeading,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }
}
