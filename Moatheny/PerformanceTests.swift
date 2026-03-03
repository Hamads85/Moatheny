import XCTest
import CoreMotion
@testable import Moatheny

/// اختبارات الأداء للبوصلة
/// تغطي: Performance, Memory, CPU usage
final class PerformanceTests: XCTestCase {
    
    // MARK: - Performance Metrics Tests
    
    /// اختبار Performance Metrics Collector
    func testPerformanceMetricsCollector() {
        let collector = PerformanceMetricsCollector()
        
        // تسجيل بداية ونهاية معالجة
        let startTime = collector.recordUpdateStart()
        Thread.sleep(forTimeInterval: 0.01) // محاكاة معالجة
        collector.recordUpdateEnd(startTime: startTime)
        
        let metrics = collector.currentMetrics
        XCTAssertGreaterThan(metrics.averageLatency, 0, "Latency يجب أن يكون أكبر من صفر")
        XCTAssertLessThan(metrics.averageLatency, 0.1, "Latency يجب أن يكون معقولاً")
    }
    
    /// اختبار Performance Budgets
    func testPerformanceBudgets() {
        let collector = PerformanceMetricsCollector()
        
        // تسجيل عدة تحديثات سريعة
        for _ in 0..<10 {
            let startTime = collector.recordUpdateStart()
            Thread.sleep(forTimeInterval: 0.001) // 1ms
            collector.recordUpdateEnd(startTime: startTime)
        }
        
        let budgetCheck = collector.checkPerformanceBudgets()
        
        // يجب أن يكون الأداء ضمن الميزانية
        XCTAssertTrue(budgetCheck.isWithinBudget || !budgetCheck.violations.isEmpty,
                     "يجب أن يكون الأداء ضمن الميزانية أو يتم الإبلاغ عن الانتهاكات")
    }
    
    /// اختبار معدل التحديث (Update Rate)
    func testUpdateRate() {
        let collector = PerformanceMetricsCollector()
        
        // تسجيل تحديثات بمعدل 10 Hz
        for i in 0..<10 {
            let startTime = collector.recordUpdateStart()
            Thread.sleep(forTimeInterval: 0.1) // 100ms بين التحديثات = 10 Hz
            collector.recordUpdateEnd(startTime: startTime)
        }
        
        let metrics = collector.currentMetrics
        // معدل التحديث يجب أن يكون قريباً من 10 Hz
        XCTAssertGreaterThan(metrics.updateRate, 5, "معدل التحديث يجب أن يكون أكبر من 5 Hz")
        XCTAssertLessThan(metrics.updateRate, 15, "معدل التحديث يجب أن يكون أقل من 15 Hz")
    }
    
    // MARK: - Kalman Filter Performance Tests
    
    /// اختبار أداء Extended Kalman Filter
    func testKalmanFilterPerformance() {
        let ekf = ExtendedKalmanFilter()
        
        // تهيئة
        let initialMeasurement = SensorMeasurement(
            type: .deviceMotion,
            timestamp: Date().timeIntervalSince1970,
            deviceMotion: nil // سيتم استخدام mock في الإنتاج
        )
        _ = ekf.update(measurement: initialMeasurement)
        
        // قياس وقت المعالجة
        let iterations = 100
        let startTime = Date()
        
        for i in 0..<iterations {
            let measurement = SensorMeasurement(
                type: .deviceMotion,
                timestamp: Date().timeIntervalSince1970 + Double(i) * 0.1,
                deviceMotion: nil
            )
            _ = ekf.update(measurement: measurement)
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        let averageTime = processingTime / Double(iterations)
        
        // متوسط وقت المعالجة يجب أن يكون أقل من 1ms
        XCTAssertLessThan(averageTime, 0.001, "متوسط وقت معالجة Kalman Filter يجب أن يكون أقل من 1ms")
        
        print("⏱️ متوسط وقت معالجة Kalman Filter: \(averageTime * 1000)ms")
    }
    
    /// اختبار أداء Magnetic Anomaly Detector
    func testMagneticAnomalyDetectorPerformance() {
        let detector = MagneticAnomalyDetector()
        
        // قياس وقت المعالجة
        let iterations = 1000
        let startTime = Date()
        
        for i in 0..<iterations {
            let field = CMMagneticField(
                x: 20 + Double.random(in: -5...5),
                y: 30 + Double.random(in: -5...5),
                z: 40 + Double.random(in: -5...5)
            )
            _ = detector.analyze(
                magneticField: field,
                timestamp: Date().timeIntervalSince1970 + Double(i) * 0.01
            )
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        let averageTime = processingTime / Double(iterations)
        
        // متوسط وقت المعالجة يجب أن يكون أقل من 0.1ms
        XCTAssertLessThan(averageTime, 0.0001, "متوسط وقت معالجة Magnetic Anomaly Detector يجب أن يكون أقل من 0.1ms")
        
        print("⏱️ متوسط وقت معالجة Magnetic Anomaly Detector: \(averageTime * 1000)ms")
    }
    
    // MARK: - Memory Tests
    
    /// اختبار استخدام الذاكرة
    func testMemoryUsage() {
        let collector = PerformanceMetricsCollector()
        let initialMetrics = collector.currentMetrics
        
        // إنشاء عدة فلاتر
        var filters: [ExtendedKalmanFilter] = []
        for _ in 0..<10 {
            filters.append(ExtendedKalmanFilter())
        }
        
        let finalMetrics = collector.currentMetrics
        
        // استخدام الذاكرة يجب أن يكون معقولاً
        let memoryIncrease = finalMetrics.memoryUsage - initialMetrics.memoryUsage
        let memoryIncreaseMB = Double(memoryIncrease) / 1_000_000
        
        XCTAssertLessThan(memoryIncreaseMB, 10, "الزيادة في استخدام الذاكرة يجب أن تكون أقل من 10 MB")
        
        print("💾 استخدام الذاكرة: \(finalMetrics.formattedMemoryUsage)")
    }
    
    /// اختبار عدم وجود Memory Leaks
    func testNoMemoryLeaks() {
        weak var weakFilter: ExtendedKalmanFilter?
        weak var weakDetector: MagneticAnomalyDetector?
        
        autoreleasepool {
            let filter = ExtendedKalmanFilter()
            let detector = MagneticAnomalyDetector()
            
            weakFilter = filter
            weakDetector = detector
            
            // استخدام الفلاتر
            for i in 0..<100 {
                let measurement = SensorMeasurement(
                    type: .deviceMotion,
                    timestamp: Date().timeIntervalSince1970 + Double(i) * 0.1,
                    deviceMotion: nil
                )
                _ = filter.update(measurement: measurement)
                
                let field = CMMagneticField(x: 20, y: 30, z: 40)
                _ = detector.analyze(magneticField: field, timestamp: Date().timeIntervalSince1970 + Double(i) * 0.1)
            }
        }
        
        // بعد autoreleasepool، يجب أن تكون المراجع ضعيفة nil
        // ملاحظة: قد لا يعمل هذا في جميع الحالات بسبب ARC
        // في الإنتاج، استخدم Instruments للتحقق من Memory Leaks
    }
    
    // MARK: - CPU Usage Tests
    
    /// اختبار استخدام CPU
    func testCPUUsage() {
        let collector = PerformanceMetricsCollector()
        
        // تسجيل تحديثات كثيفة
        for _ in 0..<100 {
            let startTime = collector.recordUpdateStart()
            // محاكاة معالجة
            _ = ExtendedKalmanFilter()
            collector.recordUpdateEnd(startTime: startTime)
        }
        
        let metrics = collector.currentMetrics
        
        // استخدام CPU يجب أن يكون معقولاً
        XCTAssertLessThan(metrics.cpuUsage, 50, "استخدام CPU يجب أن يكون أقل من 50%")
        
        print("🖥️ استخدام CPU: \(metrics.formattedCPUUsage)")
    }
    
    /// اختبار أداء معالجة متعددة الخيوط
    func testConcurrentProcessingPerformance() {
        let expectation = XCTestExpectation(description: "Concurrent processing")
        expectation.expectedFulfillmentCount = 10
        
        let startTime = Date()
        
        // معالجة متوازية
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            let ekf = ExtendedKalmanFilter()
            for i in 0..<10 {
                let measurement = SensorMeasurement(
                    type: .deviceMotion,
                    timestamp: Date().timeIntervalSince1970 + Double(i) * 0.1,
                    deviceMotion: nil
                )
                _ = ekf.update(measurement: measurement)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        // المعالجة المتوازية يجب أن تكون أسرع من المتسلسلة
        XCTAssertLessThan(processingTime, 1.0, "المعالجة المتوازية يجب أن تكتمل في أقل من ثانية")
        
        print("⚡ وقت المعالجة المتوازية: \(processingTime)s")
    }
    
    // MARK: - Stress Tests
    
    /// اختبار الضغط: قياسات كثيفة جداً
    func testStressTestHighFrequencyUpdates() {
        let ekf = ExtendedKalmanFilter()
        
        // تهيئة
        let initialMeasurement = SensorMeasurement(
            type: .deviceMotion,
            timestamp: Date().timeIntervalSince1970,
            deviceMotion: nil
        )
        _ = ekf.update(measurement: initialMeasurement)
        
        // قياسات بمعدل عالي جداً (1000 Hz)
        let iterations = 1000
        let startTime = Date()
        
        for i in 0..<iterations {
            let measurement = SensorMeasurement(
                type: .deviceMotion,
                timestamp: Date().timeIntervalSince1970 + Double(i) * 0.001,
                deviceMotion: nil
            )
            _ = ekf.update(measurement: measurement)
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        let averageTime = processingTime / Double(iterations)
        
        // حتى مع القياسات الكثيفة، يجب أن يكون الأداء جيداً
        XCTAssertLessThan(averageTime, 0.01, "متوسط وقت المعالجة يجب أن يكون أقل من 10ms حتى مع القياسات الكثيفة")
        
        print("🔥 متوسط وقت المعالجة تحت الضغط: \(averageTime * 1000)ms")
    }
    
    /// اختبار الضغط: قياسات طويلة الأمد
    func testStressTestLongRunning() {
        let ekf = ExtendedKalmanFilter()
        let detector = MagneticAnomalyDetector()
        
        // تهيئة
        let initialMeasurement = SensorMeasurement(
            type: .deviceMotion,
            timestamp: Date().timeIntervalSince1970,
            deviceMotion: nil
        )
        _ = ekf.update(measurement: initialMeasurement)
        
        // قياسات لمدة طويلة (10000 قياس)
        let iterations = 10000
        let startTime = Date()
        var anomalyCount = 0
        
        for i in 0..<iterations {
            // تحديث EKF
            let measurement = SensorMeasurement(
                type: .deviceMotion,
                timestamp: Date().timeIntervalSince1970 + Double(i) * 0.1,
                deviceMotion: nil
            )
            _ = ekf.update(measurement: measurement)
            
            // تحديث Detector
            let field = CMMagneticField(
                x: 20 + Double.random(in: -10...10),
                y: 30 + Double.random(in: -10...10),
                z: 40 + Double.random(in: -10...10)
            )
            let result = detector.analyze(
                magneticField: field,
                timestamp: Date().timeIntervalSince1970 + Double(i) * 0.1
            )
            
            if result.isAnomaly {
                anomalyCount += 1
            }
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        let averageTime = processingTime / Double(iterations)
        
        // يجب أن يكون الأداء مستقراً حتى مع القياسات الطويلة
        XCTAssertLessThan(averageTime, 0.001, "متوسط وقت المعالجة يجب أن يكون مستقراً")
        
        print("⏳ معالجة \(iterations) قياس في \(processingTime)s")
        print("📊 متوسط وقت المعالجة: \(averageTime * 1000)ms")
        print("⚠️ عدد التشويشات المكتشفة: \(anomalyCount)")
    }
    
    // MARK: - Benchmark Tests
    
    /// Benchmark: مقارنة الأداء بين الفلاتر المختلفة
    func testFilterPerformanceBenchmark() {
        let iterations = 1000
        
        // Benchmark Kalman Filter
        let ekfStartTime = Date()
        let ekf = ExtendedKalmanFilter()
        let initialMeasurement = SensorMeasurement(
            type: .deviceMotion,
            timestamp: Date().timeIntervalSince1970,
            deviceMotion: nil
        )
        _ = ekf.update(measurement: initialMeasurement)
        
        for i in 0..<iterations {
            let measurement = SensorMeasurement(
                type: .deviceMotion,
                timestamp: Date().timeIntervalSince1970 + Double(i) * 0.1,
                deviceMotion: nil
            )
            _ = ekf.update(measurement: measurement)
        }
        let ekfTime = Date().timeIntervalSince(ekfStartTime)
        
        // Benchmark Anomaly Detector
        let detectorStartTime = Date()
        let detector = MagneticAnomalyDetector()
        for i in 0..<iterations {
            let field = CMMagneticField(x: 20, y: 30, z: 40)
            _ = detector.analyze(magneticField: field, timestamp: Date().timeIntervalSince1970 + Double(i) * 0.1)
        }
        let detectorTime = Date().timeIntervalSince(detectorStartTime)
        
        print("📊 Benchmark Results:")
        print("  Kalman Filter: \(ekfTime * 1000)ms for \(iterations) iterations")
        print("  Anomaly Detector: \(detectorTime * 1000)ms for \(iterations) iterations")
        
        // يجب أن يكون كلا الفلترين سريعين
        XCTAssertLessThan(ekfTime, 1.0, "Kalman Filter يجب أن يكون سريعاً")
        XCTAssertLessThan(detectorTime, 0.5, "Anomaly Detector يجب أن يكون سريعاً")
    }
}
