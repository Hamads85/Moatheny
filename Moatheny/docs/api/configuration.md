# Configuration Guide - Compass API

## إعدادات CompassService

### المعاملات الافتراضية

```swift
// إعدادات محسنة للبوصلة
private let optimalHeadingFilter: CLLocationDirection = 1.0  // درجة واحدة
private let optimalMotionUpdateInterval: TimeInterval = 1.0 / 60.0  // 60 Hz
private let movementThreshold: Double = 0.1  // m/s²

// معاملات EKF
private let processNoiseHeading: Double = 0.05
private let processNoiseHeadingRate: Double = 0.5
private let measurementNoise: Double = 0.3

// معاملات Stability Filter
private let stabilityThreshold: Double = 0.5  // درجة
private let requiredStableReadings: Int = 1
```

### التخصيص

```swift
// لا يمكن تخصيص CompassService مباشرة
// لكن يمكن تعديل المعاملات في الكود:

// في CompassService.swift:
private let processNoiseHeading: Double = 0.1  // زيادة الاستجابة
private let measurementNoise: Double = 0.5      // تقليل الثقة في القياسات
```

## إعدادات Extended Kalman Filter

### المعاملات القابلة للتعديل

```swift
let ekf = ExtendedKalmanFilter(
    processNoise: 0.01,        // ضوضاء العملية
    measurementNoise: 0.1      // ضوضاء القياس
)
```

### تأثير المعاملات

#### processNoise (ضوضاء العملية)
- **قيمة منخفضة (0.01)**: ثقة عالية في النموذج، استجابة أبطأ
- **قيمة عالية (0.1)**: ثقة أقل في النموذج، استجابة أسرع
- **الافتراضي**: 0.01 (توازن جيد)

#### measurementNoise (ضوضاء القياس)
- **قيمة منخفضة (0.05)**: ثقة عالية في القياسات
- **قيمة عالية (0.5)**: ثقة أقل في القياسات
- **الافتراضي**: 0.1 (توازن جيد)

### أمثلة التخصيص

```swift
// للدقة العالية (استجابة أبطأ)
let highAccuracyEKF = ExtendedKalmanFilter(
    processNoise: 0.005,
    measurementNoise: 0.05
)

// للاستجابة السريعة (دقة أقل قليلاً)
let fastResponseEKF = ExtendedKalmanFilter(
    processNoise: 0.05,
    measurementNoise: 0.3
)

// للبيئات المشوشة (ثقة أقل في القياسات)
let noisyEnvironmentEKF = ExtendedKalmanFilter(
    processNoise: 0.01,
    measurementNoise: 0.5
)
```

## إعدادات Magnetic Anomaly Detector

### المعاملات القابلة للتعديل

```swift
let detector = MagneticAnomalyDetector(
    windowSize: 30,                      // حجم النافذة الزمنية
    zScoreThreshold: 2.5,                // عتبة Z-score
    minNormalMagnitude: 15.0,            // الحد الأدنى الطبيعي (μT)
    maxNormalMagnitude: 70.0,            // الحد الأقصى الطبيعي (μT)
    suspiciousMeasurementWeight: 0.3     // وزن القياسات المشكوك فيها
)
```

### تأثير المعاملات

#### windowSize
- **قيمة صغيرة (10-20)**: استجابة أسرع، دقة أقل
- **قيمة كبيرة (50-100)**: استجابة أبطأ، دقة أعلى
- **الافتراضي**: 30 (توازن جيد)

#### zScoreThreshold
- **قيمة منخفضة (2.0)**: كشف أكثر حساسية (قد يعطي false positives)
- **قيمة عالية (3.0)**: كشف أقل حساسية (قد يفوت بعض التشويشات)
- **الافتراضي**: 2.5 (توازن جيد)

#### minNormalMagnitude / maxNormalMagnitude
- **نطاق ضيق**: كشف أكثر حساسية
- **نطاق واسع**: كشف أقل حساسية
- **الافتراضي**: 15-70 μT (نطاق المجال الطبيعي للأرض)

#### suspiciousMeasurementWeight
- **قيمة منخفضة (0.1)**: تجاهل شبه كامل للقياسات المشكوك فيها
- **قيمة عالية (0.5)**: استخدام أكبر للقياسات المشكوك فيها
- **الافتراضي**: 0.3 (توازن جيد)

### أمثلة التخصيص

```swift
// للبيئات المشوشة (كشف أكثر حساسية)
let sensitiveDetector = MagneticAnomalyDetector(
    windowSize: 50,
    zScoreThreshold: 2.0,
    minNormalMagnitude: 20.0,
    maxNormalMagnitude: 60.0,
    suspiciousMeasurementWeight: 0.2
)

// للبيئات النظيفة (كشف أقل حساسية)
let relaxedDetector = MagneticAnomalyDetector(
    windowSize: 20,
    zScoreThreshold: 3.0,
    minNormalMagnitude: 10.0,
    maxNormalMagnitude: 80.0,
    suspiciousMeasurementWeight: 0.4
)
```

## إعدادات Magnetic Declination Calculator

### Cache Configuration

```swift
// في MagneticDeclinationService.swift:
private let cacheValidityDuration: TimeInterval = 3600  // ساعة واحدة
```

### استخدام API خارجي

```swift
// في MagneticDeclinationService.swift:
private let useExternalAPI: Bool = false  // استخدام API خارجي

// تفعيل API الخارجي:
private let useExternalAPI: Bool = true
private let declinationAPIURL = "https://www.ngdc.noaa.gov/geomag-web/calculators/calculateDeclination"
```

### دقة الحساب

النموذج الحالي (WMM المبسط) يعطي دقة ±1-2° في معظم المناطق.

للحصول على دقة أعلى (±0.5°):
1. تطبيق WMM الكامل (12th order)
2. استخدام API خارجي من NOAA

## إعدادات Performance Metrics Collector

### Performance Budgets

```swift
// في PerformanceMetricsCollector.swift:

// CPU Budget
if metrics.cpuUsage > 5.0 {
    violations.append("CPU usage exceeds budget")
}

// Latency Budget (60fps)
if metrics.averageLatency > 0.016 {
    violations.append("Latency exceeds budget")
}

// Memory Budget
if memoryMB > 10.0 {
    violations.append("Memory usage exceeds budget")
}

// Filter Processing Budget
if metrics.filterProcessingTime > 0.001 {
    warnings.append("Filter processing time high")
}
```

### التخصيص

```swift
// تعديل Budgets في checkPerformanceBudgets():

// CPU Budget أكثر تساهلاً
if metrics.cpuUsage > 10.0 {  // بدلاً من 5.0
    violations.append("CPU usage exceeds budget")
}

// Latency Budget أكثر تساهلاً (30fps)
if metrics.averageLatency > 0.033 {  // بدلاً من 0.016
    violations.append("Latency exceeds budget")
}
```

### تفعيل/تعطيل Performance Monitoring

```swift
// في CompassService.swift:
private var isPerformanceMonitoringEnabled = true

// تعطيل في Production:
private var isPerformanceMonitoringEnabled = false
```

## إعدادات Adaptive Update Rate Manager

### المعاملات القابلة للتعديل

```swift
// في AdaptiveUpdateRateManager.swift:

// معاملات الكشف عن الحركة
private let stationaryThreshold: Double = 0.5      // درجة/ثانية
private let slowMovementThreshold: Double = 5.0     // درجة/ثانية
private let historyWindow: TimeInterval = 0.5       // ثانية
private let maxHistorySize = 30
```

### معدلات التحديث

```swift
enum MotionState {
    case stationary      // 5 Hz
    case slowMovement    // 15 Hz
    case fastMovement    // 30 Hz
}
```

### تأثير المعاملات

#### stationaryThreshold
- **قيمة منخفضة (0.2)**: اعتبار الحركة البطيئة كحركة
- **قيمة عالية (1.0)**: اعتبار الحركة البطيئة كثبات
- **الافتراضي**: 0.5 (توازن جيد)

#### slowMovementThreshold
- **قيمة منخفضة (3.0)**: اعتبار الحركة المتوسطة كحركة سريعة
- **قيمة عالية (10.0)**: اعتبار الحركة المتوسطة كحركة بطيئة
- **الافتراضي**: 5.0 (توازن جيد)

#### historyWindow
- **قيمة صغيرة (0.2s)**: استجابة أسرع، أقل استقرار
- **قيمة كبيرة (1.0s)**: استجابة أبطأ، أكثر استقرار
- **الافتراضي**: 0.5s (توازن جيد)

### أمثلة التخصيص

```swift
// لتوفير البطارية (معدلات أقل)
enum MotionState {
    case stationary      // 2 Hz (بدلاً من 5 Hz)
    case slowMovement    // 10 Hz (بدلاً من 15 Hz)
    case fastMovement    // 20 Hz (بدلاً من 30 Hz)
}

// للدقة العالية (معدلات أعلى)
enum MotionState {
    case stationary      // 10 Hz (بدلاً من 5 Hz)
    case slowMovement    // 20 Hz (بدلاً من 15 Hz)
    case fastMovement    // 60 Hz (بدلاً من 30 Hz)
}
```

## إعدادات عامة

### Background Queue

```swift
// في CompassService.swift:
private let filterProcessingQueue = DispatchQueue(
    label: "com.moatheny.compass.filter",
    qos: .userInitiated  // يمكن تغييرها إلى .userInteractive للسرعة
)
```

### Location Manager Settings

```swift
// في CompassService.swift:
locationManager.headingFilter = 1.0  // درجة واحدة
locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
locationManager.distanceFilter = kCLDistanceFilterNone
locationManager.pausesLocationUpdatesAutomatically = false
```

## ملفات الإعداد

جميع الإعدادات موجودة في:
- `Moatheny/CompassService.swift`
- `Moatheny/ExtendedKalmanFilter.swift`
- `Moatheny/MagneticAnomalyDetector.swift`
- `Moatheny/MagneticDeclinationCalculator.swift`
- `Moatheny/PerformanceMetricsCollector.swift`
- `Moatheny/AdaptiveUpdateRateManager.swift`

## المراجع

- [Public Interfaces](./interfaces.md)
- [Usage Examples](./examples.md)
- [Architecture Overview](../architecture/overview.md)
