import Foundation
import CoreMotion

/// Extended Kalman Filter (EKF) متقدم لدمج مستشعرات البوصلة
/// 
/// ## الخوارزمية:
/// يستخدم EKF لدمج:
/// - **المغناطيسية**: قياس مباشر للـ heading
/// - **الجيروسكوب**: قياس معدل التغير (heading_rate)
///
/// ## متجه الحالة:
/// ```
/// x = [heading, heading_rate]
/// ```
/// حيث:
/// - `heading`: الاتجاه بالراديان (0-2π)
/// - `heading_rate`: معدل التغير بالراديان/ثانية
final class ExtendedKalmanFilter {
    // MARK: - State Vector
    /// متجه الحالة: [heading, heading_rate]
    private var stateHeading: Double = 0
    private var stateHeadingRate: Double = 0
    
    // MARK: - Covariance Matrix (2x2)
    /// مصفوفة التباين
    private var P00: Double = 1.0  // variance of heading
    private var P01: Double = 0.0  // covariance
    private var P10: Double = 0.0  // covariance
    private var P11: Double = 1.0  // variance of heading_rate
    
    // MARK: - Process Noise
    private let Q00: Double  // ضوضاء heading
    private let Q11: Double  // ضوضاء heading_rate
    
    // MARK: - Measurement Noise
    private let measurementNoise: Double
    
    // MARK: - Timestamp
    private var lastTimestamp: TimeInterval = 0
    
    // MARK: - Initialization Flag
    private var isInitialized: Bool = false
    
    // MARK: - Initialization
    
    /// تهيئة EKF
    /// - Parameters:
    ///   - processNoiseHeading: ضوضاء heading (عادة 0.01-0.1)
    ///   - processNoiseHeadingRate: ضوضاء heading_rate (عادة 0.1-1.0)
    ///   - measurementNoise: ضوضاء القياس المغناطيسي (عادة 0.1-0.5)
    init(
        processNoiseHeading: Double = 0.05,
        processNoiseHeadingRate: Double = 0.5,
        measurementNoise: Double = 0.3
    ) {
        self.Q00 = processNoiseHeading
        self.Q11 = processNoiseHeadingRate
        self.measurementNoise = measurementNoise
    }
    
    // MARK: - Prediction Step
    
    /// خطوة التنبؤ (Prediction Step)
    private func predict(gyroRate: Double, dt: TimeInterval) {
        guard dt > 0 && dt < 1.0 else { return }
        
        // تحديث الحالة المتوقعة
        // x_pred = F * x
        // F = [[1, dt], [0, 1]]
        let newHeading = stateHeading + dt * stateHeadingRate
        // stateHeadingRate remains the same in prediction
        
        stateHeading = newHeading
        
        // إضافة تأثير الجيروسكوب
        let gyroWeight = 0.7
        stateHeadingRate = gyroWeight * gyroRate + (1 - gyroWeight) * stateHeadingRate
        
        // تحديث مصفوفة التباين
        // P_pred = F * P * F^T + Q
        let newP00 = P00 + dt * P10 + dt * (P01 + dt * P11) + Q00
        let newP01 = P01 + dt * P11
        let newP10 = P10 + dt * P11
        let newP11 = P11 + Q11
        
        P00 = newP00
        P01 = newP01
        P10 = newP10
        P11 = newP11
        
        // تطبيع heading
        stateHeading = normalizeAngle(stateHeading)
    }
    
    // MARK: - Update Step
    
    /// خطوة التحديث (Update Step)
    func update(
        magneticHeading: Double,
        gyroRate: Double? = nil,
        timestamp: TimeInterval,
        measurementWeight: Double = 1.0
    ) -> Double {
        let dt: TimeInterval
        
        if isInitialized {
            dt = timestamp - lastTimestamp
        } else {
            dt = 0.01
            isInitialized = true
            stateHeading = magneticHeading
        }
        
        lastTimestamp = timestamp
        
        // خطوة التنبؤ
        predict(gyroRate: gyroRate ?? stateHeadingRate, dt: dt)
        
        // حساب الفرق الزاوي
        let measurementDiff = normalizeAngleDifference(magneticHeading - stateHeading)
        let innovation = measurementDiff * measurementWeight
        
        // حساب كسب Kalman
        // K = P * H^T / (H * P * H^T + R)
        // H = [1, 0]
        let S = P00 + measurementNoise
        let K0 = P00 / S
        let K1 = P10 / S
        
        // تحديث الحالة
        stateHeading = normalizeAngle(stateHeading + K0 * innovation)
        stateHeadingRate = stateHeadingRate + K1 * innovation
        
        // تحديث مصفوفة التباين
        // P = (I - K * H) * P_pred
        let newP00 = (1 - K0) * P00
        let newP01 = (1 - K0) * P01
        let newP10 = P10 - K1 * P00
        let newP11 = P11 - K1 * P01
        
        P00 = newP00
        P01 = newP01
        P10 = newP10
        P11 = newP11
        
        return stateHeading
    }
    
    // MARK: - State Access
    
    /// الحصول على heading المنعم (راديان)
    var heading: Double {
        return normalizeAngle(stateHeading)
    }
    
    /// الحصول على heading_rate (راديان/ثانية)
    var headingRate: Double {
        return stateHeadingRate
    }
    
    /// الحصول على heading بالدرجات
    var headingDegrees: Double {
        return heading * 180.0 / .pi
    }
    
    /// الحصول على uncertainty في heading (راديان)
    var headingUncertainty: Double {
        return sqrt(P00)
    }
    
    // MARK: - Reset
    
    /// إعادة تعيين الفلتر
    func reset() {
        stateHeading = 0
        stateHeadingRate = 0
        P00 = 1.0
        P01 = 0.0
        P10 = 0.0
        P11 = 1.0
        isInitialized = false
        lastTimestamp = 0
    }
    
    // MARK: - Circular Statistics Helpers
    
    /// تطبيع زاوية إلى [0, 2π)
    private func normalizeAngle(_ angle: Double) -> Double {
        var normalized = angle
        while normalized < 0 { normalized += 2 * .pi }
        while normalized >= 2 * .pi { normalized -= 2 * .pi }
        return normalized
    }
    
    /// حساب الفرق الزاوي مع مراعاة الدائرية
    private func normalizeAngleDifference(_ diff: Double) -> Double {
        var normalized = diff
        while normalized > .pi { normalized -= 2 * .pi }
        while normalized < -.pi { normalized += 2 * .pi }
        return normalized
    }
}
