import Foundation
import CoreMotion

/// كاشف التشويش المغناطيسي (Magnetic Anomaly Detector)
///
/// ## الخوارزمية:
/// يراقب magnitude المجال المغناطيسي للكشف عن:
/// - **التشويش المغناطيسي**: انحرافات مفاجئة في magnitude
/// - **المعادن القريبة**: تغييرات مستمرة في المجال
/// - **البيئة المشوشة**: تقلبات غير طبيعية
///
/// ## المبادئ:
/// 1. **Magnitude Monitoring**: المجال المغناطيسي للأرض ثابت نسبياً (~20-60 μT)
/// 2. **Statistical Analysis**: استخدام متوسط متحرك وانحراف معياري
/// 3. **Outlier Detection**: كشف القيم الشاذة باستخدام Z-score
/// 4. **Temporal Filtering**: مراعاة التغييرات الزمنية
///
/// ## خوارزمية الكشف:
/// ```
/// magnitude = sqrt(mx² + my² + mz²)
/// mean = moving_average(magnitude, window_size)
/// std = standard_deviation(magnitude, window_size)
/// z_score = |magnitude - mean| / std
/// anomaly = z_score > threshold
/// ```
final class MagneticAnomalyDetector {
    // MARK: - Configuration
    
    /// حجم النافذة الزمنية للتحليل الإحصائي
    private let windowSize: Int
    
    /// عتبة Z-score للكشف عن الشذوذ
    private let zScoreThreshold: Double
    
    /// الحد الأدنى للمجال المغناطيسي الطبيعي (μT)
    private let minNormalMagnitude: Double
    
    /// الحد الأقصى للمجال المغناطيسي الطبيعي (μT)
    private let maxNormalMagnitude: Double
    
    /// وزن القياسات المشكوك فيها (0-1)
    /// 0 = تجاهل كامل، 1 = قبول كامل
    private let suspiciousMeasurementWeight: Double
    
    // MARK: - State
    
    /// سجل magnitude القياسات
    private var magnitudeHistory: [Double] = []
    
    /// سجل timestamps
    private var timestampHistory: [TimeInterval] = []
    
    /// آخر حالة كشف
    private var lastAnomalyDetected: Bool = false
    
    /// عدد القياسات المتتالية المشكوك فيها
    private var consecutiveAnomalies: Int = 0
    
    /// آخر magnitude محسوب
    private var lastMagnitude: Double = 0
    
    // MARK: - Statistics
    
    /// المتوسط المتحرك
    private var movingAverage: Double = 0
    
    /// الانحراف المعياري المتحرك
    private var movingStdDev: Double = 0
    
    // MARK: - Initialization
    
    /// تهيئة الكاشف
    /// - Parameters:
    ///   - windowSize: حجم النافذة الزمنية (عادة 20-50)
    ///   - zScoreThreshold: عتبة Z-score (عادة 2.0-3.0)
    ///   - minNormalMagnitude: الحد الأدنى الطبيعي (μT) - عادة 15
    ///   - maxNormalMagnitude: الحد الأقصى الطبيعي (μT) - عادة 70
    ///   - suspiciousMeasurementWeight: وزن القياسات المشكوك فيها (0-1)
    init(
        windowSize: Int = 30,
        zScoreThreshold: Double = 2.5,
        minNormalMagnitude: Double = 15.0,
        maxNormalMagnitude: Double = 70.0,
        suspiciousMeasurementWeight: Double = 0.3
    ) {
        self.windowSize = windowSize
        self.zScoreThreshold = zScoreThreshold
        self.minNormalMagnitude = minNormalMagnitude
        self.maxNormalMagnitude = maxNormalMagnitude
        self.suspiciousMeasurementWeight = suspiciousMeasurementWeight
    }
    
    // MARK: - Detection
    
    /// تحليل القياس المغناطيسي والكشف عن التشويش
    /// - Parameters:
    ///   - magneticField: متجه المجال المغناطيسي (μT)
    ///   - timestamp: timestamp القياس
    /// - Returns: وزن القياس (0-1) و حالة الكشف
    func analyze(
        magneticField: CMMagneticField,
        timestamp: TimeInterval
    ) -> (weight: Double, isAnomaly: Bool, confidence: Double) {
        // حساب magnitude
        let magnitude = sqrt(
            magneticField.x * magneticField.x +
            magneticField.y * magneticField.y +
            magneticField.z * magneticField.z
        )
        
        lastMagnitude = magnitude
        
        // إضافة للتاريخ
        magnitudeHistory.append(magnitude)
        timestampHistory.append(timestamp)
        
        // الحفاظ على حجم النافذة
        if magnitudeHistory.count > windowSize {
            magnitudeHistory.removeFirst()
            timestampHistory.removeFirst()
        }
        
        // نحتاج على الأقل 5 قياسات للتحليل الإحصائي
        guard magnitudeHistory.count >= 5 else {
            return (weight: 1.0, isAnomaly: false, confidence: 0.0)
        }
        
        // حساب الإحصائيات
        updateStatistics()
        
        // الكشف عن الشذوذ
        let isAnomaly = detectAnomaly(magnitude: magnitude)
        
        // حساب وزن القياس
        let weight = calculateMeasurementWeight(isAnomaly: isAnomaly)
        
        // حساب الثقة (confidence)
        let confidence = calculateConfidence()
        
        // تحديث حالة الكشف
        if isAnomaly {
            consecutiveAnomalies += 1
            lastAnomalyDetected = true
        } else {
            consecutiveAnomalies = 0
            lastAnomalyDetected = false
        }
        
        return (weight: weight, isAnomaly: isAnomaly, confidence: confidence)
    }
    
    // MARK: - Statistics Update
    
    /// تحديث الإحصائيات (المتوسط والانحراف المعياري)
    private func updateStatistics() {
        guard magnitudeHistory.count >= 2 else { return }
        
        // حساب المتوسط
        let sum = magnitudeHistory.reduce(0, +)
        movingAverage = sum / Double(magnitudeHistory.count)
        
        // حساب الانحراف المعياري
        let variance = magnitudeHistory.map { pow($0 - movingAverage, 2) }.reduce(0, +) / Double(magnitudeHistory.count)
        movingStdDev = sqrt(variance)
        
        // حماية من الانحراف المعياري الصفر
        if movingStdDev < 0.1 {
            movingStdDev = 0.1
        }
    }
    
    // MARK: - Anomaly Detection
    
    /// كشف الشذوذ في القياس
    private func detectAnomaly(magnitude: Double) -> Bool {
        // 1. فحص النطاق الطبيعي
        if magnitude < minNormalMagnitude || magnitude > maxNormalMagnitude {
            return true
        }
        
        // 2. فحص Z-score
        if movingStdDev > 0.1 {
            let zScore = abs(magnitude - movingAverage) / movingStdDev
            if zScore > zScoreThreshold {
                return true
            }
        }
        
        // 3. فحص التغيير المفاجئ
        if magnitudeHistory.count >= 2 {
            let lastMagnitude = magnitudeHistory[magnitudeHistory.count - 2]
            let suddenChange = abs(magnitude - lastMagnitude)
            // تغيير مفاجئ أكبر من 20% من المتوسط
            if suddenChange > movingAverage * 0.2 {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Weight Calculation
    
    /// حساب وزن القياس بناءً على حالة الكشف
    private func calculateMeasurementWeight(isAnomaly: Bool) -> Double {
        if !isAnomaly {
            return 1.0
        }
        
        // إذا كان هناك عدة تشويشات متتالية، نخفض الوزن أكثر
        let consecutivePenalty = min(Double(consecutiveAnomalies) / 10.0, 0.5)
        return max(suspiciousMeasurementWeight - consecutivePenalty, 0.1)
    }
    
    // MARK: - Confidence Calculation
    
    /// حساب مستوى الثقة في القياسات
    /// - Returns: قيمة بين 0-1 (1 = ثقة عالية، 0 = ثقة منخفضة)
    private func calculateConfidence() -> Double {
        guard magnitudeHistory.count >= 5 else { return 0.0 }
        
        // نسبة القياسات الطبيعية
        let normalCount = magnitudeHistory.filter { magnitude in
            magnitude >= minNormalMagnitude && magnitude <= maxNormalMagnitude
        }.count
        let normalRatio = Double(normalCount) / Double(magnitudeHistory.count)
        
        // معامل التباين (coefficient of variation)
        let coefficientOfVariation = movingStdDev / max(movingAverage, 0.1)
        
        // الثقة تعتمد على:
        // 1. نسبة القياسات الطبيعية (أعلى = أفضل)
        // 2. معامل التباين المنخفض (أقل = أفضل)
        let stabilityScore = 1.0 - min(coefficientOfVariation / 0.3, 1.0)
        
        return normalRatio * 0.6 + stabilityScore * 0.4
    }
    
    // MARK: - State Access
    
    /// هل تم الكشف عن تشويش حالياً؟
    var isAnomalyDetected: Bool {
        return lastAnomalyDetected
    }
    
    /// عدد التشويشات المتتالية
    var consecutiveAnomalyCount: Int {
        return consecutiveAnomalies
    }
    
    /// آخر magnitude محسوب
    var currentMagnitude: Double {
        return lastMagnitude
    }
    
    /// المتوسط المتحرك الحالي
    var averageMagnitude: Double {
        return movingAverage
    }
    
    /// الانحراف المعياري الحالي
    var standardDeviation: Double {
        return movingStdDev
    }
    
    /// مستوى الثقة الحالي
    var confidence: Double {
        return calculateConfidence()
    }
    
    // MARK: - Reset
    
    /// إعادة تعيين الكاشف
    func reset() {
        magnitudeHistory.removeAll()
        timestampHistory.removeAll()
        lastAnomalyDetected = false
        consecutiveAnomalies = 0
        lastMagnitude = 0
        movingAverage = 0
        movingStdDev = 0
    }
    
    // MARK: - Diagnostics
    
    /// معلومات تشخيصية للكاشف
    var diagnostics: [String: Any] {
        return [
            "isAnomaly": lastAnomalyDetected,
            "consecutiveAnomalies": consecutiveAnomalies,
            "currentMagnitude": lastMagnitude,
            "averageMagnitude": movingAverage,
            "stdDeviation": movingStdDev,
            "confidence": calculateConfidence(),
            "historySize": magnitudeHistory.count,
            "normalRange": [minNormalMagnitude, maxNormalMagnitude]
        ]
    }
}
