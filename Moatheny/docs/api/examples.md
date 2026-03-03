# Usage Examples - Compass API

## مثال أساسي: استخدام CompassService

```swift
import SwiftUI
import CoreLocation

struct CompassView: View {
    @StateObject private var compass = CompassService()
    
    var body: some View {
        VStack {
            Text("Heading: \(Int(compass.heading))°")
                .font(.largeTitle)
            
            Text("Accuracy: \(compass.accuracy >= 0 ? "\(Int(compass.accuracy))°" : "N/A")")
                .font(.caption)
            
            if compass.calibrationNeeded {
                Text("Calibration Needed")
                    .foregroundColor(.orange)
            }
            
            if let error = compass.error {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            }
        }
        .onAppear {
            compass.startUpdating()
        }
        .onDisappear {
            compass.stopUpdating()
        }
    }
}
```

## مثال متقدم: استخدام Extended Kalman Filter

```swift
import CoreMotion

class CompassFilter {
    private let ekf = ExtendedKalmanFilter(
        processNoise: 0.05,
        measurementNoise: 0.3
    )
    
    func processHeading(_ rawHeading: Double, 
                       gyroRate: Double?, 
                       timestamp: TimeInterval) -> Double {
        // تحويل للراديان
        let headingRad = rawHeading * .pi / 180.0
        
        // إنشاء قياس
        var measurement = SensorMeasurement(
            type: .magnetometer,
            timestamp: timestamp
        )
        measurement.magneticField = CMMagneticField(
            x: cos(headingRad),
            y: sin(headingRad),
            z: 0
        )
        
        // تحديث الفلتر
        let state = ekf.update(measurement: measurement)
        
        // إرجاع Yaw بالدرجات
        var yawDeg = state.yaw * 180.0 / .pi
        while yawDeg < 0 { yawDeg += 360 }
        while yawDeg >= 360 { yawDeg -= 360 }
        
        return yawDeg
    }
    
    func reset() {
        ekf.reset()
    }
}
```

## مثال: استخدام Magnetic Anomaly Detector

```swift
import CoreMotion

class InterferenceMonitor {
    private let detector = MagneticAnomalyDetector(
        windowSize: 30,
        zScoreThreshold: 2.5,
        suspiciousMeasurementWeight: 0.3
    )
    
    func checkInterference(magneticField: CMMagneticField,
                          timestamp: TimeInterval) -> (weight: Double, 
                                                       isAnomaly: Bool) {
        let result = detector.analyze(
            magneticField: magneticField,
            timestamp: timestamp
        )
        
        if result.isAnomaly {
            print("⚠️ Interference detected!")
            print("   Weight: \(result.weight)")
            print("   Confidence: \(result.confidence)")
        }
        
        return (result.weight, result.isAnomaly)
    }
    
    func getStatus() -> String {
        if detector.isAnomalyDetected {
            return "Interference detected"
        } else {
            return "Normal"
        }
    }
}
```

## مثال: استخدام Magnetic Declination Calculator

```swift
import CoreLocation

class TrueHeadingCalculator {
    func calculateTrueHeading(magneticHeading: Double,
                             location: CLLocation) -> Double {
        // حساب الانحراف المغناطيسي
        let declination = MagneticDeclinationCalculator.calculateDeclination(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            date: location.timestamp
        )
        
        // تحويل المغناطيسي إلى الحقيقي
        let trueHeading = MagneticDeclinationCalculator.magneticToTrue(
            magneticHeading: magneticHeading,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        
        print("Magnetic Heading: \(magneticHeading)°")
        print("Declination: \(declination)°")
        print("True Heading: \(trueHeading)°")
        
        return trueHeading
    }
    
    // استخدام Extension على CLLocation
    func calculateUsingExtension(magneticHeading: Double,
                                 location: CLLocation) -> Double {
        return location.magneticToTrueHeading(magneticHeading)
    }
}
```

## مثال: استخدام Performance Metrics Collector

```swift
class PerformanceMonitor {
    private let metricsCollector = PerformanceMetricsCollector()
    
    func processHeading(_ heading: Double) {
        // تسجيل بداية المعالجة
        let startTime = metricsCollector.recordUpdateStart()
        
        // معالجة Heading (مثال)
        let processedHeading = processHeadingInternal(heading)
        
        // قياس وقت معالجة الفلتر
        let filterStartTime = Date()
        let filteredHeading = applyFilter(processedHeading)
        let filterTime = Date().timeIntervalSince(filterStartTime)
        metricsCollector.recordFilterProcessing(time: filterTime)
        
        // تسجيل نهاية المعالجة
        metricsCollector.recordUpdateEnd(startTime: startTime)
        
        // التحقق من الأداء
        let budgetCheck = metricsCollector.checkPerformanceBudgets()
        if !budgetCheck.isWithinBudget {
            print("⚠️ Performance budget violations:")
            for violation in budgetCheck.violations {
                print("   - \(violation)")
            }
        }
    }
    
    func printReport() {
        metricsCollector.printPerformanceReport()
        
        let metrics = metricsCollector.currentMetrics
        print("CPU: \(metrics.formattedCPUUsage)")
        print("Memory: \(metrics.formattedMemoryUsage)")
        print("Update Rate: \(String(format: "%.1f Hz", metrics.updateRate))")
        print("Avg Latency: \(String(format: "%.3f ms", metrics.averageLatency * 1000))")
    }
    
    private func processHeadingInternal(_ heading: Double) -> Double {
        // معالجة Heading
        return heading
    }
    
    private func applyFilter(_ heading: Double) -> Double {
        // تطبيق الفلتر
        return heading
    }
}
```

## مثال: استخدام Adaptive Update Rate Manager

```swift
class AdaptiveCompass {
    private let updateRateManager = AdaptiveUpdateRateManager()
    private var lastUpdateTime: Date?
    
    func update(heading: Double) {
        let now = Date()
        
        // تحديث حالة الحركة
        let motionState = updateRateManager.update(heading: heading, timestamp: now)
        
        // التحقق من Throttling
        guard updateRateManager.shouldUpdate(timestamp: now) else {
            return // تخطي هذا التحديث
        }
        
        // معالجة Heading
        processHeading(heading)
        
        // طباعة حالة الحركة (للتصحيح)
        if motionState != updateRateManager.motionState {
            print("Motion state changed: \(motionState.description)")
            print("Update rate: \(1.0 / motionState.updateInterval) Hz")
        }
    }
    
    func setupCallbacks() {
        updateRateManager.onStateChanged = { state in
            print("Motion state: \(state.description)")
            print("Update interval: \(state.updateInterval) seconds")
        }
        
        updateRateManager.onUpdateRateChanged = { interval in
            print("Update rate changed: \(1.0 / interval) Hz")
        }
    }
    
    private func processHeading(_ heading: Double) {
        // معالجة Heading
    }
}
```

## مثال: استخدام QiblaCalculator

```swift
import SwiftUI
import CoreLocation

struct QiblaView: View {
    @StateObject private var compass = CompassService()
    @StateObject private var locationService = LocationService()
    
    var qiblaDirection: Double {
        guard let location = locationService.currentLocation else {
            return 0
        }
        return QiblaCalculator.calculateQiblaDirection(
            from: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }
    
    var arrowRotation: Double {
        QiblaCalculator.calculateArrowRotation(
            qiblaDirection: qiblaDirection,
            deviceHeading: compass.heading
        )
    }
    
    var distance: Double {
        guard let location = locationService.currentLocation else {
            return 0
        }
        return QiblaCalculator.calculateDistanceToKaaba(
            from: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }
    
    var body: some View {
        VStack {
            // بوصلة مع سهم القبلة
            ZStack {
                // دائرة البوصلة
                Circle()
                    .stroke(Color.blue, lineWidth: 2)
                
                // سهم القبلة
                Image(systemName: "arrow.up")
                    .font(.largeTitle)
                    .foregroundColor(.green)
                    .rotationEffect(.degrees(arrowRotation))
            }
            .frame(width: 200, height: 200)
            
            // معلومات
            Text("Qibla Direction: \(Int(qiblaDirection))°")
            Text("Device Heading: \(Int(compass.heading))°")
            Text("Distance: \(String(format: "%.1f km", distance))")
        }
        .onAppear {
            compass.startUpdating()
            locationService.requestLocation()
        }
    }
}
```

## مثال: تكامل كامل مع جميع المكونات

```swift
import SwiftUI
import CoreLocation
import CoreMotion

class AdvancedCompassService: ObservableObject {
    @Published var heading: Double = 0
    @Published var accuracy: Double = -1
    @Published var interferenceLevel: String = "Normal"
    
    private let ekf = ExtendedKalmanFilter()
    private let anomalyDetector = MagneticAnomalyDetector()
    private let performanceMetrics = PerformanceMetricsCollector()
    private let updateRateManager = AdaptiveUpdateRateManager()
    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionManager()
    
    private var currentLocation: CLLocation?
    
    func start() {
        // إعداد Callbacks
        updateRateManager.onStateChanged = { [weak self] state in
            self?.updateMotionInterval(for: state)
        }
        
        // بدء المستشعرات
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
        
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                guard let motion = motion else { return }
                self?.processMotion(motion)
            }
        }
    }
    
    private func processMotion(_ motion: CMDeviceMotion) {
        let startTime = performanceMetrics.recordUpdateStart()
        
        // استخراج Heading
        let yawDeg = motion.attitude.yaw * 180 / .pi
        var headingDeg = 360.0 - yawDeg
        while headingDeg < 0 { headingDeg += 360 }
        while headingDeg >= 360 { headingDeg -= 360 }
        
        // كشف التشويش
        let magneticField = motion.magneticField
        let timestamp = Date().timeIntervalSince1970
        let interferenceResult = anomalyDetector.analyze(
            magneticField: magneticField,
            timestamp: timestamp
        )
        
        // تحديث Adaptive Update Rate
        let motionState = updateRateManager.update(heading: headingDeg, timestamp: Date())
        guard updateRateManager.shouldUpdate() else { return }
        
        // تطبيق EKF
        var measurement = SensorMeasurement(
            type: .deviceMotion,
            timestamp: timestamp
        )
        measurement.deviceMotion = motion
        let ekfState = ekf.update(measurement: measurement)
        
        // تطبيق تعويض الانحراف
        var finalHeading = ekfState.yaw * 180 / .pi
        if let location = currentLocation {
            finalHeading = MagneticDeclinationCalculator.magneticToTrue(
                magneticHeading: finalHeading,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
        }
        
        // تحديث UI
        DispatchQueue.main.async { [weak self] in
            self?.heading = finalHeading
            self?.interferenceLevel = interferenceResult.isAnomaly ? "Interference" : "Normal"
        }
        
        // تسجيل الأداء
        let filterTime = Date().timeIntervalSince(startTime)
        performanceMetrics.recordFilterProcessing(time: filterTime)
        performanceMetrics.recordUpdateEnd(startTime: startTime)
    }
    
    private func updateMotionInterval(for state: AdaptiveUpdateRateManager.MotionState) {
        motionManager.deviceMotionUpdateInterval = state.updateInterval
    }
}

extension AdvancedCompassService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, 
                        didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
}
```

## المراجع

- [Public Interfaces](./interfaces.md)
- [Configuration Guide](./configuration.md)
- [Architecture Overview](../architecture/overview.md)
