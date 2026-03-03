# Debugging Guide - Compass System

## نظرة عامة

هذا الدليل يشرح كيفية تصحيح الأخطاء في نظام البوصلة باستخدام أدوات مختلفة.

## أدوات التصحيح

### 1. Xcode Debugger

#### Breakpoints

**وضع Breakpoints في نقاط مهمة:**
```swift
// في CompassService.startUpdating():
func startUpdating() {
    // Breakpoint هنا
    guard !isUpdating else { return }
    isUpdating = true
    
    // Breakpoint هنا للتحقق من حالة الإذن
    let authStatus = locationManager.authorizationStatus
    
    // Breakpoint هنا للتحقق من بدء التحديثات
    locationManager.startUpdatingHeading()
}
```

**Conditional Breakpoints:**
```
// Breakpoint عند accuracy > 25
compass.accuracy > 25

// Breakpoint عند كشف تشويش
detector.isAnomalyDetected == true
```

#### LLDB Commands

```lldb
# طباعة قيمة heading
po compass.heading

# طباعة حالة EKF
po extendedKalmanFilter?.state

# طباعة Performance Metrics
po performanceMetrics.currentMetrics

# طباعة Anomaly Detector Diagnostics
po detector.diagnostics

# تتبع تحديثات heading
watchpoint set variable compass.heading
```

### 2. Console Logging

#### Debug Logging في CompassService

```swift
// تفعيل Debug Logging:
private var isDebugLoggingEnabled = true

func debugLog(_ message: String, 
              data: [String: Any] = [:],
              level: DebugLevel = .info) {
    guard isDebugLoggingEnabled else { return }
    
    let prefix: String
    switch level {
    case .info: prefix = "ℹ️"
    case .warning: prefix = "⚠️"
    case .error: prefix = "❌"
    case .success: prefix = "✅"
    }
    
    print("\(prefix) [Compass] \(message)")
    if !data.isEmpty {
        for (key, value) in data {
            print("   \(key): \(value)")
        }
    }
}

enum DebugLevel {
    case info, warning, error, success
}
```

#### استخدام Debug Logging

```swift
// في startUpdating():
debugLog("Starting compass updates", level: .info)

// عند تحديث heading:
debugLog("Heading updated", data: [
    "heading": heading,
    "accuracy": accuracy,
    "source": source
])

// عند كشف تشويش:
debugLog("Interference detected", data: [
    "weight": result.weight,
    "confidence": result.confidence,
    "magnitude": detector.currentMagnitude
], level: .warning)
```

### 3. Performance Monitoring

#### تفعيل Performance Monitoring

```swift
// في CompassService:
private var isPerformanceMonitoringEnabled = true

// طباعة تقرير دوري:
private var performanceReportTimer: Timer?

func startPerformanceMonitoring() {
    performanceReportTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
        self?.performanceMetrics.printPerformanceReport()
        
        let budgetCheck = self?.performanceMetrics.checkPerformanceBudgets()
        if let violations = budgetCheck?.violations, !violations.isEmpty {
            print("⚠️ Performance Budget Violations:")
            for violation in violations {
                print("   - \(violation)")
            }
        }
    }
}
```

#### تحليل Performance Metrics

```swift
// الحصول على Metrics:
let metrics = performanceMetrics.currentMetrics

// تحليل Latency:
if metrics.averageLatency > 0.016 {
    print("⚠️ Latency exceeds 60fps budget")
    print("   Average: \(metrics.averageLatency * 1000)ms")
    print("   Max: \(metrics.maxLatency * 1000)ms")
}

// تحليل CPU Usage:
if metrics.cpuUsage > 5.0 {
    print("⚠️ CPU usage exceeds budget")
    print("   Current: \(metrics.formattedCPUUsage)")
}

// تحليل Memory:
let memoryMB = Double(metrics.memoryUsage) / 1_000_000
if memoryMB > 10.0 {
    print("⚠️ Memory usage exceeds budget")
    print("   Current: \(metrics.formattedMemoryUsage)")
}

// تحليل Update Rate:
if metrics.updateRate < 5.0 {
    print("⚠️ Update rate too low")
    print("   Current: \(String(format: "%.1f Hz", metrics.updateRate))")
}
```

### 4. Instruments

#### Time Profiler

**استخدام Time Profiler لتحليل الأداء:**
1. افتح Instruments في Xcode
2. اختر "Time Profiler"
3. شغل التطبيق
4. راجع Call Tree:
   - ابحث عن `CompassService`
   - ابحث عن `ExtendedKalmanFilter`
   - ابحث عن `MagneticAnomalyDetector`

**نقاط مهمة للتحليل:**
- وقت معالجة `processHeadingOnBackground`
- وقت `ekf.update()`
- وقت `detector.analyze()`

#### Allocations

**استخدام Allocations لتحليل الذاكرة:**
1. افتح Instruments
2. اختر "Allocations"
3. شغل التطبيق
4. راجع Memory Graph:
   - ابحث عن تسريبات الذاكرة
   - راجع استخدام الذاكرة للمكونات

**نقاط مهمة:**
- `magnitudeHistory` في Anomaly Detector
- `headingHistory` في Adaptive Update Rate Manager
- `updateTimestamps` في Performance Metrics Collector

#### Energy Log

**استخدام Energy Log لتحليل استهلاك البطارية:**
1. افتح Instruments
2. اختر "Energy Log"
3. شغل التطبيق
4. راجع Energy Usage:
   - CPU Usage
   - Location Services
   - Motion Services

### 5. Custom Debug Views

#### Debug Overlay في UI

```swift
struct CompassDebugOverlay: View {
    @ObservedObject var compass: CompassService
    let detector: MagneticAnomalyDetector
    let metrics: PerformanceMetricsCollector
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Debug Info")
                .font(.headline)
            
            Group {
                Text("Heading: \(Int(compass.heading))°")
                Text("Raw: \(Int(compass.rawHeading))°")
                Text("Accuracy: \(compass.accuracy >= 0 ? "\(Int(compass.accuracy))°" : "N/A")")
                Text("Pitch: \(Int(compass.pitch))°")
                Text("Roll: \(Int(compass.roll))°")
                Text("Is Flat: \(compass.isDeviceFlat ? "Yes" : "No")")
                Text("Calibration: \(compass.calibrationNeeded ? "Needed" : "OK")")
            }
            
            Divider()
            
            Group {
                Text("Interference:")
                Text("  Detected: \(detector.isAnomalyDetected ? "Yes" : "No")")
                Text("  Confidence: \(String(format: "%.2f", detector.confidence))")
                Text("  Magnitude: \(String(format: "%.1f", detector.currentMagnitude)) μT")
            }
            
            Divider()
            
            Group {
                Text("Performance:")
                let m = metrics.currentMetrics
                Text("  CPU: \(m.formattedCPUUsage)")
                Text("  Memory: \(m.formattedMemoryUsage)")
                Text("  Update Rate: \(String(format: "%.1f Hz", m.updateRate))")
                Text("  Latency: \(String(format: "%.2f ms", m.averageLatency * 1000))")
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .foregroundColor(.white)
        .font(.system(size: 12, design: .monospaced))
    }
}
```

#### استخدام Debug Overlay

```swift
struct QiblaView: View {
    @StateObject private var compass = CompassService()
    @State private var showDebug = false
    
    var body: some View {
        ZStack {
            // البوصلة
            CompassView(compass: compass)
            
            // Debug Overlay
            if showDebug {
                VStack {
                    HStack {
                        Spacer()
                        CompassDebugOverlay(
                            compass: compass,
                            detector: compass.anomalyDetector,
                            metrics: compass.performanceMetrics
                        )
                    }
                    Spacer()
                }
            }
        }
        .onTapGesture(count: 3) {
            showDebug.toggle()
        }
    }
}
```

## سيناريوهات التصحيح

### السيناريو 1: تتبع مشكلة في الدقة

**الخطوات:**
1. تفعيل Debug Logging
2. وضع Breakpoints في `ingestHeading`
3. تتبع القيم:
   - `rawHeading`
   - `ekf.state.yaw`
   - `finalHeading`
4. التحقق من:
   - تطبيق EKF بشكل صحيح
   - تطبيق Declination بشكل صحيح
   - عدم وجود تشويش

**Code:**
```swift
func ingestHeading(_ headingValue: Double, source: String) {
    debugLog("Ingesting heading", data: [
        "raw": headingValue,
        "source": source
    ])
    
    rawHeading = headingValue
    
    let kalmanSmoothed = smoothHeadingWithKalman(headingValue)
    debugLog("After EKF", data: ["smoothed": kalmanSmoothed])
    
    let stableHeading = applyStabilityFilter(kalmanSmoothed)
    debugLog("After stability filter", data: ["stable": stableHeading])
    
    heading = stableHeading
}
```

### السيناريو 2: تحليل مشكلة الأداء

**الخطوات:**
1. تفعيل Performance Monitoring
2. استخدام Time Profiler
3. تحديد Bottlenecks:
   - وقت `ekf.update()`
   - وقت `detector.analyze()`
   - وقت `calculateDeclination()`
4. تحسين المكونات البطيئة

**Code:**
```swift
func processHeadingOnBackground(motion: CMDeviceMotion, headingDeg: Double) {
    let startTime = performanceMetrics.recordUpdateStart()
    
    // قياس وقت EKF
    let ekfStartTime = Date()
    let smoothed = smoothHeadingWithKalman(headingDeg)
    let ekfTime = Date().timeIntervalSince(ekfStartTime)
    
    if ekfTime > 0.001 {
        debugLog("EKF processing slow", data: [
            "time": ekfTime * 1000,
            "threshold": 1.0
        ], level: .warning)
    }
    
    performanceMetrics.recordFilterProcessing(time: ekfTime)
    performanceMetrics.recordUpdateEnd(startTime: startTime)
}
```

### السيناريو 3: تتبع مشكلة في التشويش

**الخطوات:**
1. تفعيل Debug Logging في Anomaly Detector
2. تتبع:
   - `magnitude`
   - `movingAverage`
   - `movingStdDev`
   - `zScore`
3. التحقق من:
   - حساب Magnitude بشكل صحيح
   - تحديث Statistics بشكل صحيح
   - تطبيق Thresholds بشكل صحيح

**Code:**
```swift
func analyze(magneticField: CMMagneticField, timestamp: TimeInterval) -> ... {
    let magnitude = sqrt(
        magneticField.x * magneticField.x +
        magneticField.y * magneticField.y +
        magneticField.z * magneticField.z
    )
    
    debugLog("Analyzing magnetic field", data: [
        "magnitude": magnitude,
        "x": magneticField.x,
        "y": magneticField.y,
        "z": magneticField.z
    ])
    
    updateStatistics()
    
    debugLog("Statistics updated", data: [
        "average": movingAverage,
        "stdDev": movingStdDev,
        "historySize": magnitudeHistory.count
    ])
    
    let isAnomaly = detectAnomaly(magnitude: magnitude)
    
    if isAnomaly {
        let zScore = abs(magnitude - movingAverage) / movingStdDev
        debugLog("Anomaly detected", data: [
            "zScore": zScore,
            "threshold": zScoreThreshold,
            "magnitude": magnitude,
            "average": movingAverage
        ], level: .warning)
    }
    
    // ...
}
```

## Best Practices

### 1. استخدام Debug Flags

```swift
#if DEBUG
private var isDebugLoggingEnabled = true
#else
private var isDebugLoggingEnabled = false
#endif
```

### 2. Structured Logging

```swift
struct DebugLog {
    let timestamp: Date
    let component: String
    let message: String
    let data: [String: Any]
    let level: DebugLevel
}

var debugLogs: [DebugLog] = []

func log(_ log: DebugLog) {
    #if DEBUG
    debugLogs.append(log)
    if debugLogs.count > 1000 {
        debugLogs.removeFirst(100)
    }
    #endif
}
```

### 3. Export Debug Data

```swift
func exportDebugData() -> Data {
    let logs = debugLogs.map { log in
        [
            "timestamp": log.timestamp.timeIntervalSince1970,
            "component": log.component,
            "message": log.message,
            "data": log.data,
            "level": log.level.rawValue
        ]
    }
    
    return try! JSONSerialization.data(withJSONObject: logs)
}
```

## المراجع

- [Troubleshooting Guide](./troubleshooting.md)
- [Performance Tuning](./performance.md)
- [API Documentation](../api/interfaces.md)
