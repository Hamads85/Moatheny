# Performance Tuning Guide - Compass System

## نظرة عامة

هذا الدليل يشرح كيفية ضبط وتحسين أداء نظام البوصلة.

## Performance Budgets

### الميزانيات الحالية

```swift
CPU Usage: < 5% average
Memory: < 10MB for compass processing
Latency: < 16ms (60fps)
Update Rate: 5-30 Hz (adaptive)
Filter Processing: < 1ms
```

### التحقق من الميزانيات

```swift
let budgetCheck = performanceMetrics.checkPerformanceBudgets()
if !budgetCheck.isWithinBudget {
    for violation in budgetCheck.violations {
        print("❌ \(violation)")
    }
    for warning in budgetCheck.warnings {
        print("⚠️ \(warning)")
    }
}
```

## تحسينات الأداء

### 1. تحسين Extended Kalman Filter

#### تقليل حجم الحسابات

**المشكلة:** EKF يحتاج حسابات مصفوفات معقدة.

**الحل:**
```swift
// استخدام Matrix operations محسنة
// تجنب إنشاء matrices جديدة في كل مرة
private var cachedStateTransitionMatrix: Matrix?
private var cachedMeasurementMatrix: Matrix?

func predict(dt: TimeInterval) -> EKFState {
    // استخدام cached matrix إذا كان dt نفسه
    if let cached = cachedStateTransitionMatrix, lastDt == dt {
        // استخدام cached
    } else {
        // حساب جديد
        let F = calculateStateTransitionMatrix(dt: dt)
        cachedStateTransitionMatrix = F
    }
    // ...
}
```

#### تحسين Matrix Operations

```swift
// استخدام SIMD للعمليات الرياضية
import Accelerate

func matrixMultiply(_ a: Matrix, _ b: Matrix) -> Matrix {
    // استخدام vDSP للضرب السريع
    // ...
}
```

### 2. تحسين Magnetic Anomaly Detector

#### تقليل حجم History

**المشكلة:** حفظ تاريخ كبير يستهلك ذاكرة.

**الحل:**
```swift
// تقليل windowSize في البيئات المحدودة الذاكرة
#if os(iOS) && !targetEnvironment(simulator)
private let windowSize: Int = 20  // بدلاً من 30
#else
private let windowSize: Int = 30
#endif
```

#### تحسين حساب Statistics

```swift
// استخدام incremental statistics بدلاً من إعادة الحساب
private var sum: Double = 0
private var sumSquared: Double = 0

func updateStatistics() {
    // تحديث incremental بدلاً من إعادة الحساب الكامل
    if let newValue = magnitudeHistory.last {
        sum += newValue
        sumSquared += newValue * newValue
        
        if magnitudeHistory.count > windowSize,
           let oldValue = magnitudeHistory.first {
            sum -= oldValue
            sumSquared -= oldValue * oldValue
        }
    }
    
    movingAverage = sum / Double(magnitudeHistory.count)
    let variance = (sumSquared / Double(magnitudeHistory.count)) - (movingAverage * movingAverage)
    movingStdDev = sqrt(max(0, variance))
}
```

### 3. تحسين Adaptive Update Rate

#### تحسين حساب Angular Velocity

**المشكلة:** حساب Angular Velocity في كل تحديث.

**الحل:**
```swift
// Cache النتيجة إذا لم يتغير التاريخ
private var cachedAngularVelocity: Double?
private var lastHistoryHash: Int = 0

func calculateAngularVelocity() -> Double {
    let currentHash = headingHistory.hashValue
    if currentHash == lastHistoryHash, let cached = cachedAngularVelocity {
        return cached
    }
    
    // حساب جديد
    let velocity = calculateAngularVelocityInternal()
    cachedAngularVelocity = velocity
    lastHistoryHash = currentHash
    
    return velocity
}
```

### 4. تحسين Performance Metrics Collector

#### تقليل Frequency

**المشكلة:** جمع Metrics في كل تحديث يستهلك موارد.

**الحل:**
```swift
// جمع Metrics كل N تحديثات فقط
private var metricsUpdateCounter: Int = 0
private let metricsUpdateInterval: Int = 10  // كل 10 تحديثات

func recordUpdateEnd(startTime: Date) {
    latencyMeasurements.append(Date().timeIntervalSince(startTime))
    
    metricsUpdateCounter += 1
    if metricsUpdateCounter >= metricsUpdateInterval {
        metricsUpdateCounter = 0
        // تحديث Metrics فقط هنا
        updateMetrics()
    }
}
```

#### تعطيل في Production

```swift
#if DEBUG
private var isPerformanceMonitoringEnabled = true
#else
private var isPerformanceMonitoringEnabled = false
#endif
```

### 5. تحسين Background Processing

#### استخدام Background Queue

```swift
// التأكد من استخدام background queue
private let filterProcessingQueue = DispatchQueue(
    label: "com.moatheny.compass.filter",
    qos: .userInitiated  // يمكن تغييرها إلى .utility لتوفير البطارية
)
```

#### Batch Processing

```swift
// معالجة عدة قراءات معاً
private var pendingReadings: [SensorReading] = []
private let batchSize = 5

func processReadings() {
    guard pendingReadings.count >= batchSize else { return }
    
    // معالجة batch
    let batch = pendingReadings.prefix(batchSize)
    processBatch(batch)
    
    pendingReadings.removeFirst(batchSize)
}
```

## تحسينات استهلاك البطارية

### 1. Adaptive Update Rate

**الاستخدام:**
```swift
// التأكد من تفعيل Adaptive Update Rate
let updateRateManager = AdaptiveUpdateRateManager()

// عند الثبات: 5 Hz
// عند الحركة البطيئة: 15 Hz
// عند الحركة السريعة: 30 Hz
```

**التخصيص:**
```swift
// تقليل المعدلات لتوفير البطارية
enum MotionState {
    case stationary: return 1.0 / 2.0   // 2 Hz
    case slowMovement: return 1.0 / 10.0  // 10 Hz
    case fastMovement: return 1.0 / 20.0  // 20 Hz
}
```

### 2. تعطيل المكونات غير الضرورية

```swift
// تعطيل Performance Monitoring في Production
#if !DEBUG
private var isPerformanceMonitoringEnabled = false
#endif

// تعطيل Debug Logging
#if !DEBUG
private var isDebugLoggingEnabled = false
#endif
```

### 3. تقليل Location Updates

```swift
// استخدام distanceFilter لتقليل Location Updates
locationManager.distanceFilter = 10.0  // تحديث كل 10 أمتار

// أو استخدام headingFilter
locationManager.headingFilter = 2.0  // تحديث كل 2 درجة
```

## تحسينات الذاكرة

### 1. تقليل History Sizes

```swift
// تقليل windowSize في Anomaly Detector
private let windowSize: Int = 20  // بدلاً من 30

// تقليل maxHistorySize في Adaptive Update Rate
private let maxHistorySize = 20  // بدلاً من 30
```

### 2. تنظيف الذاكرة

```swift
// تنظيف History القديم بانتظام
func cleanupOldHistory() {
    let cutoffTime = Date().addingTimeInterval(-historyWindow)
    cleanupOldHistory(before: cutoffTime)
}

// تنظيف Cache في Declination Calculator
func cleanOldCache() {
    let now = Date()
    declinationCache = declinationCache.filter { _, value in
        now.timeIntervalSince(value.timestamp) < cacheValidityDuration
    }
}
```

### 3. استخدام Weak References

```swift
// استخدام weak references في Callbacks
adaptiveUpdateRate.onStateChanged = { [weak self] state in
    self?.updateMotionManagerInterval(for: state)
}
```

## Monitoring و Profiling

### 1. استخدام Instruments

**Time Profiler:**
- تحديد Bottlenecks
- تحليل Call Tree
- تحسين Hot Paths

**Allocations:**
- كشف Memory Leaks
- تحليل Memory Usage
- تحسين Memory Footprint

**Energy Log:**
- تحليل استهلاك البطارية
- تحديد المكونات المستهلكة
- تحسين Energy Efficiency

### 2. Custom Metrics

```swift
// إضافة Metrics مخصصة
struct CustomMetrics {
    var ekfProcessingTime: TimeInterval
    var anomalyDetectionTime: TimeInterval
    var declinationCalculationTime: TimeInterval
    var totalProcessingTime: TimeInterval
}

var customMetrics = CustomMetrics()

func recordCustomMetrics() {
    let startTime = Date()
    
    // EKF Processing
    let ekfStart = Date()
    let ekfResult = ekf.update(...)
    customMetrics.ekfProcessingTime = Date().timeIntervalSince(ekfStart)
    
    // Anomaly Detection
    let anomalyStart = Date()
    let anomalyResult = detector.analyze(...)
    customMetrics.anomalyDetectionTime = Date().timeIntervalSince(anomalyStart)
    
    // Declination Calculation
    let declinationStart = Date()
    let declination = calculator.calculateDeclination(...)
    customMetrics.declinationCalculationTime = Date().timeIntervalSince(declinationStart)
    
    customMetrics.totalProcessingTime = Date().timeIntervalSince(startTime)
    
    // طباعة إذا كان بطيئاً
    if customMetrics.totalProcessingTime > 0.016 {
        print("⚠️ Total processing time exceeds 16ms")
        print("   EKF: \(customMetrics.ekfProcessingTime * 1000)ms")
        print("   Anomaly: \(customMetrics.anomalyDetectionTime * 1000)ms")
        print("   Declination: \(customMetrics.declinationCalculationTime * 1000)ms")
    }
}
```

## Best Practices

### 1. Profile First, Optimize Later

- قم بقياس الأداء أولاً
- حدد Bottlenecks الفعلية
- ركز على Hot Paths

### 2. Use Appropriate Data Structures

```swift
// استخدام Array بدلاً من Dictionary للـ History
// Array أسرع للـ append و removeFirst
private var magnitudeHistory: [Double] = []  // ✅
// private var magnitudeHistory: [Int: Double] = [:]  // ❌
```

### 3. Avoid Premature Optimization

- لا تحسن قبل القياس
- ركز على المشاكل الفعلية
- احتفظ بالكود البسيط

### 4. Test Performance Changes

```swift
// اختبار التغييرات
func testPerformance() {
    let iterations = 1000
    let startTime = Date()
    
    for _ in 0..<iterations {
        // العملية المراد قياسها
        processHeading(180.0)
    }
    
    let elapsed = Date().timeIntervalSince(startTime)
    let average = elapsed / Double(iterations)
    
    print("Average time: \(average * 1000)ms")
    print("Throughput: \(Double(iterations) / elapsed) ops/sec")
}
```

## المراجع

- [Troubleshooting Guide](./troubleshooting.md)
- [Debugging Guide](./debugging.md)
- [API Documentation](../api/interfaces.md)
