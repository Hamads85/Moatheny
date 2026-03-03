# إصلاحات مراجعة الكود - تطبيق بوصلة القبلة

هذا الملف يحتوي على الكود المقترح لإصلاح المشاكل المكتشفة في مراجعة الكود.

---

## 🔴 الإصلاحات الحرجة

### 1. إصلاح تسريب بيانات الموقع في Production Logs

**الملف:** `Views.swift`  
**السطر:** 2310-2312

**قبل:**
```swift
print("📍 الموقع: \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
print("🕋 اتجاه القبلة: \(qiblaDirection)°")
print("📏 المسافة: \(distance) كم")
```

**بعد:**
```swift
#if DEBUG
print("📍 الموقع: \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
print("🕋 اتجاه القبلة: \(qiblaDirection)°")
print("📏 المسافة: \(distance) كم")
#endif
```

---

### 2. إصلاح Race Condition في CompassService

**الملف:** `CompassService.swift`  
**السطر:** 524-543

**قبل:**
```swift
private func ingestHeading(_ headingValue: Double, source: String, startTime: Date? = nil) {
    let processingStartTime = startTime ?? Date()
    
    rawHeading = headingValue
    
    // معالجة الفلاتر (قد تكون على background queue)
    let kalmanSmoothed = smoothHeadingWithKalman(headingValue)
    let stableHeading = applyStabilityFilter(kalmanSmoothed)
    
    // تحديث UI على Main Thread
    DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        self.heading = stableHeading
        
        // تسجيل نهاية المعالجة للأداء
        if let startTime = startTime {
            self.performanceMetrics.recordUpdateEnd(startTime: startTime)
        }
    }
}
```

**بعد:**
```swift
// إضافة serial queue للـ heading updates
private let headingUpdateQueue = DispatchQueue(label: "com.moatheny.compass.heading", qos: .userInitiated)

private func ingestHeading(_ headingValue: Double, source: String, startTime: Date? = nil) {
    let processingStartTime = startTime ?? Date()
    
    // تحديث rawHeading على serial queue
    headingUpdateQueue.async { [weak self] in
        guard let self = self else { return }
        
        // معالجة الفلاتر
        let kalmanSmoothed = self.smoothHeadingWithKalman(headingValue)
        let stableHeading = self.applyStabilityFilter(kalmanSmoothed)
        
        // تحديث UI على Main Thread
        DispatchQueue.main.async {
            self.rawHeading = headingValue
            self.heading = stableHeading
            
            // تسجيل نهاية المعالجة للأداء
            if let startTime = startTime {
                self.performanceMetrics.recordUpdateEnd(startTime: startTime)
            }
        }
    }
}
```

---

### 3. إصلاح Memory Leak في AdaptiveUpdateRateManager

**الملف:** `CompassService.swift`  
**السطر:** 283-297

**قبل:**
```swift
func stopUpdating() {
    guard isUpdating else { return }
    isUpdating = false
    locationManager.stopUpdatingHeading()
    locationManager.stopUpdatingLocation()
    motionManager.stopDeviceMotionUpdates()
    
    // إيقاف Performance Monitoring
    stopPerformanceMonitoring()
    
    // إعادة تعيين Adaptive Update Rate
    adaptiveUpdateRate.reset()
    
    print("⏹ توقف تحديث البوصلة")
}
```

**بعد:**
```swift
func stopUpdating() {
    guard isUpdating else { return }
    isUpdating = false
    locationManager.stopUpdatingHeading()
    locationManager.stopUpdatingLocation()
    motionManager.stopDeviceMotionUpdates()
    
    // إيقاف Performance Monitoring
    stopPerformanceMonitoring()
    
    // تنظيف callbacks لمنع retain cycles
    adaptiveUpdateRate.onStateChanged = nil
    adaptiveUpdateRate.onUpdateRateChanged = nil
    
    // إعادة تعيين Adaptive Update Rate
    adaptiveUpdateRate.reset()
    
    print("⏹ توقف تحديث البوصلة")
}
```

---

### 4. إضافة Nil Checks في ExtendedKalmanFilter

**الملف:** `ExtendedKalmanFilter.swift`  
**السطر:** 98-99

**قبل:**
```swift
private func predict(gyroRate: Double, dt: TimeInterval) {
    guard dt > 0 && dt < 1.0 else { return }
    // ...
}
```

**بعد:**
```swift
private func predict(gyroRate: Double, dt: TimeInterval) {
    guard dt > 0 && dt < 1.0 && dt.isFinite && !dt.isNaN else {
        return
    }
    
    guard gyroRate.isFinite && !gyroRate.isNaN else {
        return
    }
    // ...
}
```

---

## 🟡 الإصلاحات الموصى بها

### 5. استبدال Magic Numbers بثوابت

**الملف:** `CompassService.swift`  
**السطر:** 33-57

**قبل:**
```swift
// إعدادات محسنة للبوصلة
private let optimalHeadingFilter: CLLocationDirection = 1.0
private let optimalMotionUpdateInterval: TimeInterval = 1.0 / 60.0
private let movementThreshold: Double = 0.1

// ====== معاملات EKF - محسنة للسرعة والدقة ======
private let processNoiseHeading: Double = 0.05
private let processNoiseHeadingRate: Double = 0.5
private let measurementNoise: Double = 0.3

// ====== فلتر إضافي للتذبذب السريع - محسن ======
private let stabilityThreshold: Double = 0.5
private let requiredStableReadings: Int = 1
```

**بعد:**
```swift
// MARK: - Constants
private struct CompassConstants {
    // إعدادات البوصلة
    static let optimalHeadingFilter: CLLocationDirection = 1.0 // درجة واحدة
    static let optimalMotionUpdateInterval: TimeInterval = 1.0 / 60.0 // 60 Hz
    static let movementThreshold: Double = 0.1 // m/s²
    
    // معاملات EKF
    static let processNoiseHeading: Double = 0.05
    static let processNoiseHeadingRate: Double = 0.5
    static let measurementNoise: Double = 0.3
    
    // فلتر الاستقرار
    static let stabilityThreshold: Double = 0.5 // درجة
    static let requiredStableReadings: Int = 1
}

// استخدام الثوابت
private let optimalHeadingFilter = CompassConstants.optimalHeadingFilter
private let optimalMotionUpdateInterval = CompassConstants.optimalMotionUpdateInterval
private let movementThreshold = CompassConstants.movementThreshold
private let processNoiseHeading = CompassConstants.processNoiseHeading
private let processNoiseHeadingRate = CompassConstants.processNoiseHeadingRate
private let measurementNoise = CompassConstants.measurementNoise
private let stabilityThreshold = CompassConstants.stabilityThreshold
private let requiredStableReadings = CompassConstants.requiredStableReadings
```

---

### 6. تقليل Complexity في updateDeviceOrientation

**الملف:** `CompassService.swift`  
**السطر:** 311-427

**قبل:** (دالة واحدة طويلة)

**بعد:**
```swift
private func updateDeviceOrientation(_ motion: CMDeviceMotion) {
    updatePitchAndRoll(motion)
    determineDeviceOrientation(from: motion)
    logDeviceOrientationIfNeeded()
}

private func updatePitchAndRoll(_ motion: CMDeviceMotion) {
    let attitude = motion.attitude
    
    // الميل (pitch) - الأمام/الخلف (بالدرجات)
    pitch = attitude.pitch * 180 / .pi
    
    // الدوران (roll) - الجانبي (بالدرجات)
    roll = attitude.roll * 180 / .pi
    
    // التحقق من وضعية الجهاز - مسطح إذا كان الميل أقل من 45 درجة
    isDeviceFlat = abs(pitch) < 45 && abs(roll) < 45
}

private func determineDeviceOrientation(from motion: CMDeviceMotion) {
    // تحديث وضعية الجهاز من UIDevice
    let currentOrientation = UIDevice.current.orientation
    if currentOrientation != .unknown {
        deviceOrientation = currentOrientation
    }
    
    // استخدام gravity من CMDeviceMotion للكشف الدقيق عن الوضعية
    let gravity = motion.gravity
    let gravityMagnitude = sqrt(gravity.x * gravity.x + gravity.y * gravity.y + gravity.z * gravity.z)
    
    // إذا كانت الجاذبية قريبة من 1.0، الجهاز ثابت نسبياً
    guard gravityMagnitude > 0.7 && gravityMagnitude < 1.3 else { return }
    
    let absGravityX = abs(gravity.x)
    let absGravityY = abs(gravity.y)
    let absGravityZ = abs(gravity.z)
    
    // تحديد الوضعية الأكثر احتمالاً بناءً على gravity
    if absGravityZ > max(absGravityX, absGravityY) {
        // Face Up أو Face Down
        deviceOrientation = gravity.z > 0 ? .faceDown : .faceUp
    } else if absGravityY > absGravityX {
        // Portrait أو Portrait Upside Down
        deviceOrientation = gravity.y < 0 ? .portrait : .portraitUpsideDown
    } else {
        // Landscape Left أو Right
        deviceOrientation = gravity.x < 0 ? .landscapeLeft : .landscapeRight
    }
}

private func logDeviceOrientationIfNeeded() {
    let sec = Int(Date().timeIntervalSince1970)
    guard sec != lastLogSecond else { return }
    
    lastLogSecond = sec
    let o = UIDevice.current.orientation
    let oStr: String = {
        switch o {
        case .portrait: return "portrait"
        case .portraitUpsideDown: return "portraitUpsideDown"
        case .landscapeLeft: return "landscapeLeft"
        case .landscapeRight: return "landscapeRight"
        case .faceUp: return "faceUp"
        case .faceDown: return "faceDown"
        default: return "unknown"
        }
    }()
    lastDeviceOrientationRaw = oStr
    
    DebugFileLogger.log(
        runId: "qibla-accuracy",
        hypothesisId: "Q1",
        location: "CompassService.swift:updateDeviceOrientation",
        message: "Device motion attitude tick",
        data: [
            "pitchDeg": Int(pitch.rounded()),
            "rollDeg": Int(roll.rounded()),
            "isFlat": isDeviceFlat,
            "deviceOrientation": oStr
        ]
    )
}
```

---

### 7. إضافة @MainActor لـ QiblaView

**الملف:** `Views.swift`  
**السطر:** 1993

**قبل:**
```swift
struct QiblaView: View {
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var cityStore: CityStore
    @StateObject private var compass = CompassService()
    // ...
}
```

**بعد:**
```swift
@MainActor
struct QiblaView: View {
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var cityStore: CityStore
    @StateObject private var compass = CompassService()
    // ...
}
```

---

### 8. تحسين Error Handling في PerformanceMetricsCollector

**الملف:** `PerformanceMetricsCollector.swift`  
**السطر:** 214-230

**قبل:**
```swift
private func getCurrentMemoryUsage() -> Int64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_,
                     task_flavor_t(MACH_TASK_BASIC_INFO),
                     $0,
                     &count)
        }
    }
    
    guard kerr == KERN_SUCCESS else { return 0 }
    
    return Int64(info.resident_size)
}
```

**بعد:**
```swift
private func getCurrentMemoryUsage() -> Int64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_,
                     task_flavor_t(MACH_TASK_BASIC_INFO),
                     $0,
                     &count)
        }
    }
    
    guard kerr == KERN_SUCCESS else {
        logger.warning("Failed to get memory usage: \(kerr)")
        return -1 // قيمة خاصة تشير للفشل
    }
    
    return Int64(info.resident_size)
}
```

---

### 9. إزالة Duplicate Code في normalizeAngle

**إنشاء ملف جديد:** `Double+AngleExtensions.swift`

```swift
import Foundation

extension Double {
    /// تطبيع زاوية إلى [0, 360) بالدرجات
    func normalizedAngleDegrees() -> Double {
        var normalized = self.truncatingRemainder(dividingBy: 360)
        if normalized < 0 { normalized += 360 }
        return normalized
    }
    
    /// تطبيع زاوية إلى [0, 2π) بالراديان
    func normalizedAngleRadians() -> Double {
        var normalized = self
        while normalized < 0 { normalized += 2 * .pi }
        while normalized >= 2 * .pi { normalized -= 2 * .pi }
        return normalized
    }
}
```

**استخدام في CompassService.swift:**
```swift
// قبل:
private func normalizeAngle(_ angle: Double) -> Double {
    var normalized = angle.truncatingRemainder(dividingBy: 360)
    if normalized < 0 { normalized += 360 }
    return normalized
}

// بعد:
// استخدام extension
let normalized = angle.normalizedAngleDegrees()
```

**استخدام في ExtendedKalmanFilter.swift:**
```swift
// قبل:
private func normalizeAngle(_ angle: Double) -> Double {
    var normalized = angle
    while normalized < 0 { normalized += 2 * .pi }
    while normalized >= 2 * .pi { normalized -= 2 * .pi }
    return normalized
}

// بعد:
// استخدام extension
let normalized = angle.normalizedAngleRadians()
```

---

## 📝 ملاحظات التنفيذ

1. **ترتيب الأولويات:** ابدأ بالإصلاحات الحرجة أولاً
2. **Testing:** اختبر كل إصلاح بشكل منفصل
3. **Code Review:** اطلب مراجعة الكود بعد كل إصلاح
4. **Documentation:** حدّث التعليقات عند الحاجة

---

**تاريخ الإنشاء:** 30 يناير 2026  
**آخر تحديث:** 30 يناير 2026
