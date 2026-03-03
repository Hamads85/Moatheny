# Troubleshooting Guide - Compass System

## نظرة عامة

هذا الدليل يساعد في استكشاف وحل المشاكل الشائعة في نظام البوصلة.

## المشاكل الشائعة

### 1. البوصلة لا تعمل

#### الأعراض
- `isAvailable = false`
- `error` يحتوي على رسالة خطأ
- لا توجد قراءات للـ heading

#### التشخيص

**الخطوة 1: التحقق من توفر البوصلة**
```swift
if !CLLocationManager.headingAvailable() {
    print("❌ البوصلة غير متوفرة على هذا الجهاز")
}
```

**الخطوة 2: التحقق من إذن الموقع**
```swift
let authStatus = locationManager.authorizationStatus
switch authStatus {
case .denied, .restricted:
    print("❌ إذن الموقع مرفوض")
case .notDetermined:
    print("⏳ إذن الموقع لم يُحدد بعد")
default:
    print("✅ إذن الموقع متاح")
}
```

**الخطوة 3: التحقق من حالة التحديث**
```swift
if !compass.isUpdating {
    print("⚠️ البوصلة متوقفة")
}
```

#### الحلول

1. **طلب إذن الموقع:**
```swift
compass.requestLocationPermission()
```

2. **بدء التحديثات:**
```swift
compass.startUpdating()
```

3. **التحقق من الإعدادات:**
   - تأكد من تفعيل Location Services في Settings
   - تأكد من تفعيل Compass في Privacy & Security

### 2. دقة منخفضة

#### الأعراض
- `accuracy > 25°`
- `calibrationNeeded = true`
- قراءات متذبذبة

#### التشخيص

**الخطوة 1: فحص الدقة**
```swift
if compass.accuracy > 25 {
    print("⚠️ الدقة منخفضة: \(compass.accuracy)°")
}
```

**الخطوة 2: فحص حالة المعايرة**
```swift
if compass.calibrationNeeded {
    print("⚠️ تحتاج معايرة")
}
```

**الخطوة 3: فحص التشويش المغناطيسي**
```swift
if detector.isAnomalyDetected {
    print("⚠️ تم الكشف عن تشويش مغناطيسي")
    print("   Confidence: \(detector.confidence)")
}
```

#### الحلول

1. **معايرة البوصلة:**
   - اتبع تعليمات iOS للمعايرة (حركة 8)
   - تأكد من عدم وجود معادن قريبة

2. **الابتعاد عن مصادر التشويش:**
   - أجهزة إلكترونية
   - هياكل معدنية
   - مغناطيسات

3. **التحقق من الموقع:**
```swift
if let location = currentLocation {
    let accuracy = MagneticDeclinationCalculator.estimateAccuracy(
        latitude: location.coordinate.latitude,
        longitude: location.coordinate.longitude
    )
    print("Expected declination accuracy: ±\(accuracy)°")
}
```

### 3. استهلاك بطارية عالي

#### الأعراض
- استهلاك بطارية سريع
- حرارة الجهاز
- CPU usage عالي

#### التشخيص

**الخطوة 1: فحص Performance Metrics**
```swift
let metrics = performanceMetrics.currentMetrics
print("CPU Usage: \(metrics.formattedCPUUsage)")
print("Update Rate: \(String(format: "%.1f Hz", metrics.updateRate))")
```

**الخطوة 2: فحص Adaptive Update Rate**
```swift
let state = adaptiveUpdateRate.motionState
print("Motion State: \(state.description)")
print("Update Rate: \(1.0 / state.updateInterval) Hz")
```

**الخطوة 3: فحص Performance Budgets**
```swift
let budgetCheck = performanceMetrics.checkPerformanceBudgets()
if !budgetCheck.isWithinBudget {
    for violation in budgetCheck.violations {
        print("⚠️ \(violation)")
    }
}
```

#### الحلول

1. **تعطيل Performance Monitoring في Production:**
```swift
private var isPerformanceMonitoringEnabled = false
```

2. **تقليل معدل التحديث:**
```swift
// في AdaptiveUpdateRateManager:
case .stationary: return 1.0 / 2.0  // 2 Hz بدلاً من 5 Hz
```

3. **استخدام Background Queue:**
```swift
// التأكد من استخدام background queue للفلاتر
filterProcessingQueue.async { ... }
```

### 4. قراءات غير مستقرة

#### الأعراض
- تذبذب في القراءات
- تغييرات مفاجئة في الاتجاه
- عدم استقرار السهم

#### التشخيص

**الخطوة 1: فحص Raw Heading**
```swift
print("Raw Heading: \(compass.rawHeading)°")
print("Smoothed Heading: \(compass.heading)°")
```

**الخطوة 2: فحص EKF State**
```swift
if let ekf = extendedKalmanFilter {
    print("EKF Initialized: \(ekf.isInitialized)")
    print("EKF State: \(ekf.state)")
}
```

**الخطوة 3: فحص Anomaly Detector**
```swift
print("Anomaly Detected: \(detector.isAnomalyDetected)")
print("Confidence: \(detector.confidence)")
print("Standard Deviation: \(detector.standardDeviation)")
```

#### الحلول

1. **زيادة Stability Threshold:**
```swift
private let stabilityThreshold: Double = 1.0  // بدلاً من 0.5
```

2. **تعديل EKF Parameters:**
```swift
// تقليل ضوضاء القياس للاستقرار
private let measurementNoise: Double = 0.2  // بدلاً من 0.3
```

3. **إعادة تعيين الفلاتر:**
```swift
extendedKalmanFilter?.reset()
magneticAnomalyDetector?.reset()
adaptiveUpdateRate.reset()
```

### 5. اتجاه القبلة غير دقيق

#### الأعراض
- اتجاه القبلة يختلف عن المتوقع
- خطأ كبير في الاتجاه

#### التشخيص

**الخطوة 1: التحقق من حساب القبلة**
```swift
let qiblaDirection = QiblaCalculator.calculateQiblaDirection(
    from: latitude,
    longitude: longitude
)
print("Qibla Direction: \(qiblaDirection)°")
```

**الخطوة 2: التحقق من الانحراف المغناطيسي**
```swift
let declination = MagneticDeclinationCalculator.calculateDeclination(
    latitude: latitude,
    longitude: longitude
)
print("Magnetic Declination: \(declination)°")
```

**الخطوة 3: التحقق من Heading**
```swift
print("Magnetic Heading: \(magneticHeading)°")
print("True Heading: \(trueHeading)°")
```

#### الحلول

1. **التحقق من الموقع:**
   - تأكد من دقة GPS
   - انتظر حتى يتم تحديد الموقع بدقة

2. **التحقق من الانحراف:**
```swift
// استخدام True Heading بدلاً من Magnetic Heading
let trueHeading = MagneticDeclinationCalculator.magneticToTrue(
    magneticHeading: compass.heading,
    latitude: location.coordinate.latitude,
    longitude: location.coordinate.longitude
)
```

3. **معايرة البوصلة:**
   - اتبع تعليمات المعايرة
   - تأكد من عدم وجود تشويش

## أدوات التشخيص

### Debug Logging

```swift
// تفعيل Debug Logging في CompassService:
private var isDebugLoggingEnabled = true

func debugLog(_ message: String, data: [String: Any] = [:]) {
    guard isDebugLoggingEnabled else { return }
    print("🔍 [Compass] \(message)")
    for (key, value) in data {
        print("   \(key): \(value)")
    }
}
```

### Performance Monitoring

```swift
// طباعة تقرير الأداء:
performanceMetrics.printPerformanceReport()

// التحقق من Budgets:
let budgetCheck = performanceMetrics.checkPerformanceBudgets()
if budgetCheck.hasIssues {
    print("⚠️ Performance Issues:")
    for violation in budgetCheck.violations {
        print("   - \(violation)")
    }
    for warning in budgetCheck.warnings {
        print("   ⚠️ \(warning)")
    }
}
```

### Diagnostics Info

```swift
// معلومات تشخيصية من Anomaly Detector:
let diagnostics = detector.diagnostics
print("Anomaly Detector Diagnostics:")
for (key, value) in diagnostics {
    print("   \(key): \(value)")
}
```

## سيناريوهات محددة

### السيناريو 1: البوصلة لا تعمل بعد التثبيت

**الخطوات:**
1. التحقق من إذن الموقع
2. التحقق من توفر البوصلة على الجهاز
3. إعادة تشغيل التطبيق
4. التحقق من إعدادات الخصوصية

### السيناريو 2: دقة منخفضة في مبنى

**الخطوات:**
1. الخروج من المبنى
2. معايرة البوصلة
3. التحقق من عدم وجود معادن قريبة
4. استخدام True Heading بدلاً من Magnetic Heading

### السيناريو 3: استهلاك بطارية عالي

**الخطوات:**
1. تعطيل Performance Monitoring
2. تقليل معدل التحديث
3. استخدام Adaptive Update Rate
4. التحقق من Background App Refresh

## المراجع

- [Debugging Guide](./debugging.md)
- [Performance Tuning](./performance.md)
- [API Documentation](../api/interfaces.md)
