import XCTest
import CoreMotion
@testable import Moatheny

/// اختبارات شاملة للفلاتر المستخدمة في البوصلة
/// تغطي: Extended Kalman Filter, Magnetic Anomaly Detector, Stability Filter
final class FilterTests: XCTestCase {
    
    // MARK: - Extended Kalman Filter Tests
    
    /// اختبار تهيئة Extended Kalman Filter
    func testExtendedKalmanFilterInitialization() {
        let ekf = ExtendedKalmanFilter(
            processNoise: 0.01,
            measurementNoise: 0.1
        )
        
        XCTAssertFalse(ekf.isInitialized, "الفلتر يجب أن يبدأ غير مهيأ")
        XCTAssertEqual(ekf.processNoise, 0.01, accuracy: 0.001)
        XCTAssertEqual(ekf.measurementNoise, 0.1, accuracy: 0.001)
    }
    
    /// اختبار التنبؤ (Prediction) في EKF
    func testEKFPrediction() {
        let ekf = ExtendedKalmanFilter()
        
        // تهيئة الفلتر بقياس أولي
        let initialMeasurement = SensorMeasurement(
            type: .deviceMotion,
            timestamp: Date().timeIntervalSince1970,
            deviceMotion: nil // سيتم استخدام mock في الإنتاج
        )
        
        _ = ekf.update(measurement: initialMeasurement)
        
        // التنبؤ بخطوة زمنية
        let predictedState = ekf.predict(dt: 0.1)
        
        // يجب أن تكون الحالة في نطاق معقول
        XCTAssertGreaterThanOrEqual(predictedState.roll, -Double.pi)
        XCTAssertLessThanOrEqual(predictedState.roll, Double.pi)
        XCTAssertGreaterThanOrEqual(predictedState.pitch, -Double.pi)
        XCTAssertLessThanOrEqual(predictedState.pitch, Double.pi)
    }
    
    /// اختبار التحديث (Update) في EKF مع Accelerometer
    func testEKFUpdateWithAccelerometer() {
        let ekf = ExtendedKalmanFilter()
        
        let measurement = SensorMeasurement(
            type: .accelerometer,
            timestamp: Date().timeIntervalSince1970,
            acceleration: CMAcceleration(x: 0, y: 0, z: -9.8)
        )
        
        let updatedState = ekf.update(measurement: measurement)
        
        // بعد التحديث الأول، يجب أن يكون الفلتر مهيأ
        XCTAssertTrue(ekf.isInitialized, "الفلتر يجب أن يكون مهيأ بعد التحديث")
        
        // يجب أن تكون الزوايا في نطاق معقول
        XCTAssertGreaterThanOrEqual(updatedState.roll, -Double.pi)
        XCTAssertLessThanOrEqual(updatedState.roll, Double.pi)
    }
    
    /// اختبار التحديث (Update) في EKF مع Gyroscope
    func testEKFUpdateWithGyroscope() {
        let ekf = ExtendedKalmanFilter()
        
        // تهيئة أولية
        let initialMeasurement = SensorMeasurement(
            type: .accelerometer,
            timestamp: Date().timeIntervalSince1970,
            acceleration: CMAcceleration(x: 0, y: 0, z: -9.8)
        )
        _ = ekf.update(measurement: initialMeasurement)
        
        // تحديث مع Gyroscope
        let gyroMeasurement = SensorMeasurement(
            type: .gyroscope,
            timestamp: Date().timeIntervalSince1970 + 0.1,
            rotationRate: CMRotationRate(x: 0.1, y: 0.2, z: 0.3)
        )
        
        let updatedState = ekf.update(measurement: gyroMeasurement)
        
        // يجب أن تكون معدلات الدوران محدثة
        XCTAssertNotNil(updatedState.rollRate)
        XCTAssertNotNil(updatedState.pitchRate)
        XCTAssertNotNil(updatedState.yawRate)
    }
    
    /// اختبار التحديث (Update) في EKF مع Magnetometer
    func testEKFUpdateWithMagnetometer() {
        let ekf = ExtendedKalmanFilter()
        
        // تهيئة أولية
        let initialMeasurement = SensorMeasurement(
            type: .accelerometer,
            timestamp: Date().timeIntervalSince1970,
            acceleration: CMAcceleration(x: 0, y: 0, z: -9.8)
        )
        _ = ekf.update(measurement: initialMeasurement)
        
        // تحديث مع Magnetometer
        let magMeasurement = SensorMeasurement(
            type: .magnetometer,
            timestamp: Date().timeIntervalSince1970 + 0.1,
            magneticField: CMMagneticField(x: 20, y: 5, z: 45),
            magneticAccuracy: .high
        )
        
        let updatedState = ekf.update(measurement: magMeasurement)
        
        // يجب أن يكون Yaw محدثاً
        XCTAssertGreaterThanOrEqual(updatedState.yaw, -Double.pi)
        XCTAssertLessThanOrEqual(updatedState.yaw, Double.pi)
    }
    
    /// اختبار إعادة تعيين EKF
    func testEKFReset() {
        let ekf = ExtendedKalmanFilter()
        
        // تهيئة الفلتر
        let measurement = SensorMeasurement(
            type: .accelerometer,
            timestamp: Date().timeIntervalSince1970,
            acceleration: CMAcceleration(x: 0, y: 0, z: -9.8)
        )
        _ = ekf.update(measurement: measurement)
        XCTAssertTrue(ekf.isInitialized)
        
        // إعادة التعيين
        ekf.reset()
        XCTAssertFalse(ekf.isInitialized, "الفلتر يجب أن يكون غير مهيأ بعد إعادة التعيين")
    }
    
    /// اختبار تطبيع الزوايا في EKF
    func testEKFAngleNormalization() {
        let ekf = ExtendedKalmanFilter()
        
        // تهيئة بزاوية كبيرة (سيتم تطبيعها)
        let measurement = SensorMeasurement(
            type: .accelerometer,
            timestamp: Date().timeIntervalSince1970,
            acceleration: CMAcceleration(x: 0, y: 0, z: -9.8)
        )
        
        let state = ekf.update(measurement: measurement)
        
        // يجب أن تكون الزوايا مطبعة بين -π و π
        XCTAssertGreaterThanOrEqual(state.roll, -Double.pi)
        XCTAssertLessThanOrEqual(state.roll, Double.pi)
        XCTAssertGreaterThanOrEqual(state.pitch, -Double.pi)
        XCTAssertLessThanOrEqual(state.pitch, Double.pi)
    }
    
    /// اختبار استقرار EKF مع قياسات متعددة
    func testEKFStabilityWithMultipleMeasurements() {
        let ekf = ExtendedKalmanFilter()
        
        // تهيئة
        let initialMeasurement = SensorMeasurement(
            type: .accelerometer,
            timestamp: Date().timeIntervalSince1970,
            acceleration: CMAcceleration(x: 0, y: 0, z: -9.8)
        )
        _ = ekf.update(measurement: initialMeasurement)
        
        // إضافة قياسات متعددة مع ضوضاء صغيرة
        var previousYaw = 0.0
        for i in 1...10 {
            let timestamp = Date().timeIntervalSince1970 + Double(i) * 0.1
            let noise = Double.random(in: -0.01...0.01)
            let measurement = SensorMeasurement(
                type: .magnetometer,
                timestamp: timestamp,
                magneticField: CMMagneticField(x: 20 + noise, y: 5 + noise, z: 45 + noise),
                magneticAccuracy: .high
            )
            
            let state = ekf.update(measurement: measurement)
            
            // يجب أن يكون الفلتر مستقراً (التغييرات صغيرة)
            let yawChange = abs(state.yaw - previousYaw)
            XCTAssertLessThan(yawChange, 0.1, "الفلتر يجب أن يكون مستقراً مع الضوضاء الصغيرة")
            
            previousYaw = state.yaw
        }
    }
    
    // MARK: - Magnetic Anomaly Detector Tests
    
    /// اختبار تهيئة Magnetic Anomaly Detector
    func testMagneticAnomalyDetectorInitialization() {
        let detector = MagneticAnomalyDetector(
            windowSize: 30,
            zScoreThreshold: 2.5,
            minNormalMagnitude: 15.0,
            maxNormalMagnitude: 70.0,
            suspiciousMeasurementWeight: 0.3
        )
        
        XCTAssertFalse(detector.isAnomalyDetected, "الكاشف يجب أن يبدأ بدون كشف تشويش")
        XCTAssertEqual(detector.consecutiveAnomalyCount, 0)
    }
    
    /// اختبار كشف المجال المغناطيسي الطبيعي
    func testMagneticAnomalyDetectorNormalField() {
        let detector = MagneticAnomalyDetector()
        
        // إضافة قياسات طبيعية (magnitude ~50 μT)
        for i in 0..<10 {
            let field = CMMagneticField(x: 20 + Double.random(in: -5...5),
                                       y: 30 + Double.random(in: -5...5),
                                       z: 40 + Double.random(in: -5...5))
            let result = detector.analyze(
                magneticField: field,
                timestamp: Date().timeIntervalSince1970 + Double(i) * 0.1
            )
            
            // بعد عدة قياسات، يجب أن يكون الكشف طبيعياً
            if i >= 5 {
                XCTAssertFalse(result.isAnomaly, "المجال الطبيعي يجب ألا يُكتشف كتشويش")
                XCTAssertEqual(result.weight, 1.0, accuracy: 0.1, "الوزن يجب أن يكون 1.0 للمجال الطبيعي")
            }
        }
    }
    
    /// اختبار كشف التشويش المغناطيسي (magnitude عالي)
    func testMagneticAnomalyDetectorHighMagnitude() {
        let detector = MagneticAnomalyDetector()
        
        // إضافة قياسات طبيعية أولاً
        for i in 0..<10 {
            let field = CMMagneticField(x: 20, y: 30, z: 40)
            _ = detector.analyze(
                magneticField: field,
                timestamp: Date().timeIntervalSince1970 + Double(i) * 0.1
            )
        }
        
        // إضافة قياس مشوش (magnitude عالي جداً)
        let anomalousField = CMMagneticField(x: 200, y: 200, z: 200) // magnitude ~346 μT
        let result = detector.analyze(
            magneticField: anomalousField,
            timestamp: Date().timeIntervalSince1970 + 1.0
        )
        
        XCTAssertTrue(result.isAnomaly, "المجال عالي Magnitude يجب أن يُكتشف كتشويش")
        XCTAssertLessThan(result.weight, 1.0, "الوزن يجب أن يكون أقل من 1.0 للقياس المشوش")
    }
    
    /// اختبار كشف التشويش المغناطيسي (magnitude منخفض)
    func testMagneticAnomalyDetectorLowMagnitude() {
        let detector = MagneticAnomalyDetector()
        
        // إضافة قياسات طبيعية أولاً
        for i in 0..<10 {
            let field = CMMagneticField(x: 20, y: 30, z: 40)
            _ = detector.analyze(
                magneticField: field,
                timestamp: Date().timeIntervalSince1970 + Double(i) * 0.1
            )
        }
        
        // إضافة قياس مشوش (magnitude منخفض جداً)
        let anomalousField = CMMagneticField(x: 1, y: 1, z: 1) // magnitude ~1.7 μT
        let result = detector.analyze(
            magneticField: anomalousField,
            timestamp: Date().timeIntervalSince1970 + 1.0
        )
        
        XCTAssertTrue(result.isAnomaly, "المجال منخفض Magnitude يجب أن يُكتشف كتشويش")
    }
    
    /// اختبار حساب الثقة (Confidence) في Magnetic Anomaly Detector
    func testMagneticAnomalyDetectorConfidence() {
        let detector = MagneticAnomalyDetector()
        
        // إضافة قياسات طبيعية
        for i in 0..<20 {
            let field = CMMagneticField(x: 20 + Double.random(in: -2...2),
                                       y: 30 + Double.random(in: -2...2),
                                       z: 40 + Double.random(in: -2...2))
            _ = detector.analyze(
                magneticField: field,
                timestamp: Date().timeIntervalSince1970 + Double(i) * 0.1
            )
        }
        
        let confidence = detector.confidence
        XCTAssertGreaterThanOrEqual(confidence, 0.0)
        XCTAssertLessThanOrEqual(confidence, 1.0)
        XCTAssertGreaterThan(confidence, 0.5, "الثقة يجب أن تكون عالية مع القياسات الطبيعية")
    }
    
    /// اختبار إعادة تعيين Magnetic Anomaly Detector
    func testMagneticAnomalyDetectorReset() {
        let detector = MagneticAnomalyDetector()
        
        // إضافة قياسات
        for i in 0..<10 {
            let field = CMMagneticField(x: 20, y: 30, z: 40)
            _ = detector.analyze(
                magneticField: field,
                timestamp: Date().timeIntervalSince1970 + Double(i) * 0.1
            )
        }
        
        XCTAssertGreaterThan(detector.currentMagnitude, 0)
        
        // إعادة التعيين
        detector.reset()
        
        XCTAssertEqual(detector.currentMagnitude, 0)
        XCTAssertFalse(detector.isAnomalyDetected)
        XCTAssertEqual(detector.consecutiveAnomalyCount, 0)
    }
    
    // MARK: - Stability Filter Tests (من CompassService)
    
    /// اختبار فلتر الاستقرار مع تغييرات صغيرة
    func testStabilityFilterSmallChanges() {
        // محاكاة فلتر الاستقرار
        var lastStableHeading: Double = 0
        let stabilityThreshold: Double = 0.5
        var consecutiveSmallChanges: Int = 0
        let requiredStableReadings: Int = 1
        
        func applyStabilityFilter(_ heading: Double) -> Double {
            var diff = heading - lastStableHeading
            if diff > 180 { diff -= 360 }
            if diff < -180 { diff += 360 }
            
            if abs(diff) < stabilityThreshold {
                consecutiveSmallChanges += 1
                if consecutiveSmallChanges >= requiredStableReadings {
                    lastStableHeading = heading
                    consecutiveSmallChanges = 0
                }
                return lastStableHeading
            } else {
                consecutiveSmallChanges = 0
                lastStableHeading = heading
                return heading
            }
        }
        
        // اختبار تغييرات صغيرة (يجب تجاهلها)
        let result1 = applyStabilityFilter(0.3) // تغيير صغير
        XCTAssertEqual(result1, 0.0, accuracy: 0.1, "التغيير الصغير يجب أن يُتجاهل")
        
        // اختبار تغيير كبير (يجب قبوله)
        let result2 = applyStabilityFilter(10.0) // تغيير كبير
        XCTAssertEqual(result2, 10.0, accuracy: 0.1, "التغيير الكبير يجب أن يُقبل")
    }
    
    /// اختبار فلتر الاستقرار مع الانتقال الزاوي (359° → 0°)
    func testStabilityFilterAngularWrapAround() {
        var lastStableHeading: Double = 359.0
        let stabilityThreshold: Double = 0.5
        
        func applyStabilityFilter(_ heading: Double) -> Double {
            var diff = heading - lastStableHeading
            if diff > 180 { diff -= 360 }
            if diff < -180 { diff += 360 }
            
            if abs(diff) < stabilityThreshold {
                return lastStableHeading
            } else {
                lastStableHeading = heading
                return heading
            }
        }
        
        // اختبار الانتقال من 359° إلى 1°
        let result = applyStabilityFilter(1.0)
        // الفرق = 1 - 359 = -358 → +360 = 2°
        // يجب أن يُقبل لأن 2° > 0.5°
        XCTAssertEqual(result, 1.0, accuracy: 0.1, "الانتقال من 359° إلى 1° يجب أن يُقبل")
    }
}
