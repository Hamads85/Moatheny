# Public Interfaces - Compass API

## CompassService

الخدمة الرئيسية للبوصلة. توفر واجهة موحدة للوصول إلى قراءات البوصلة.

### Published Properties

```swift
@Published var heading: Double              // الاتجاه الحقيقي المنعم (0-360)
@Published var rawHeading: Double           // الاتجاه الخام قبل التنعيم
@Published var accuracy: Double              // دقة القراءة (-1 إذا غير متاح)
@Published var isAvailable: Bool             // هل البوصلة متاحة
@Published var error: String?                 // رسالة الخطأ
@Published var pitch: Double                 // الميل للأمام/الخلف (بالدرجات)
@Published var roll: Double                   // الميل للجانب (بالدرجات)
@Published var isDeviceFlat: Bool             // هل الجهاز مسطح
@Published var calibrationNeeded: Bool         // هل تحتاج معايرة
@Published var deviceOrientation: UIDeviceOrientation  // وضعية الجهاز
@Published var isDeviceMoving: Bool           // هل الجهاز يتحرك
@Published var tiltCompensationEnabled: Bool // تفعيل تعويض الميلان
```

### Public Methods

#### startUpdating()
بدء تحديثات البوصلة.

```swift
func startUpdating()
```

**الاستخدام:**
```swift
let compass = CompassService()
compass.startUpdating()
```

**ملاحظات:**
- يطلب إذن الموقع تلقائياً إذا لم يُمنح
- يبدأ تحديثات CoreLocation و CoreMotion
- يهيئ الفلاتر تلقائياً

#### stopUpdating()
إيقاف تحديثات البوصلة.

```swift
func stopUpdating()
```

**الاستخدام:**
```swift
compass.stopUpdating()
```

**ملاحظات:**
- يوقف جميع المستشعرات
- يوفر البطارية

#### requestLocationPermission()
طلب إذن الموقع.

```swift
func requestLocationPermission()
```

**الاستخدام:**
```swift
compass.requestLocationPermission()
```

**ملاحظات:**
- يطلب WhenInUse أولاً
- يمكن طلب Always authorization لاحقاً

#### setTiltCompensation(_ enabled: Bool)
تفعيل/تعطيل تعويض الميلان.

```swift
func setTiltCompensation(_ enabled: Bool)
```

**الاستخدام:**
```swift
compass.setTiltCompensation(true)  // تفعيل
compass.setTiltCompensation(false) // تعطيل
```

#### getOrientationInfo()
الحصول على معلومات الوضعية.

```swift
func getOrientationInfo() -> (orientation: UIDeviceOrientation, 
                              isFlat: Bool, 
                              pitch: Double, 
                              roll: Double)
```

**الاستخدام:**
```swift
let info = compass.getOrientationInfo()
print("Orientation: \(info.orientation)")
print("Is Flat: \(info.isFlat)")
print("Pitch: \(info.pitch)°")
print("Roll: \(info.roll)°")
```

## ExtendedKalmanFilter

فلتر Kalman الممتد لتنعيم قراءات البوصلة.

### Initialization

```swift
init(processNoise: Double = 0.01, 
     measurementNoise: Double = 0.1)
```

**المعاملات:**
- `processNoise`: ضوضاء العملية (افتراضي: 0.01)
- `measurementNoise`: ضوضاء القياس (افتراضي: 0.1)

### Public Methods

#### predict(dt: TimeInterval)
التنبؤ بالحالة التالية.

```swift
func predict(dt: TimeInterval) -> EKFState
```

**المعاملات:**
- `dt`: الفترة الزمنية منذ آخر تحديث

**الإرجاع:**
- `EKFState`: الحالة المتوقعة

#### update(measurement: SensorMeasurement)
تحديث الحالة بناءً على قياس جديد.

```swift
func update(measurement: SensorMeasurement) -> EKFState
```

**المعاملات:**
- `measurement`: قياس من أحد المستشعرات

**الإرجاع:**
- `EKFState`: الحالة المحدثة

#### reset()
إعادة تعيين الفلتر.

```swift
func reset()
```

### Properties

```swift
var state: EKFState              // الحالة الحالية
var covariance: Matrix           // مصفوفة التباين
var isInitialized: Bool          // هل تم التهيئة
var processNoise: Double          // ضوضاء العملية
var measurementNoise: Double      // ضوضاء القياس
```

## MagneticAnomalyDetector

كاشف التشويش المغناطيسي.

### Initialization

```swift
init(windowSize: Int = 30,
     zScoreThreshold: Double = 2.5,
     minNormalMagnitude: Double = 15.0,
     maxNormalMagnitude: Double = 70.0,
     suspiciousMeasurementWeight: Double = 0.3)
```

**المعاملات:**
- `windowSize`: حجم النافذة الزمنية (افتراضي: 30)
- `zScoreThreshold`: عتبة Z-score (افتراضي: 2.5)
- `minNormalMagnitude`: الحد الأدنى الطبيعي (افتراضي: 15.0 μT)
- `maxNormalMagnitude`: الحد الأقصى الطبيعي (افتراضي: 70.0 μT)
- `suspiciousMeasurementWeight`: وزن القياسات المشكوك فيها (افتراضي: 0.3)

### Public Methods

#### analyze(magneticField:timestamp:)
تحليل القياس المغناطيسي.

```swift
func analyze(magneticField: CMMagneticField,
             timestamp: TimeInterval) -> (weight: Double, 
                                         isAnomaly: Bool, 
                                         confidence: Double)
```

**المعاملات:**
- `magneticField`: متجه المجال المغناطيسي
- `timestamp`: timestamp القياس

**الإرجاع:**
- `weight`: وزن القياس (0-1)
- `isAnomaly`: هل تم الكشف عن تشويش
- `confidence`: مستوى الثقة (0-1)

#### reset()
إعادة تعيين الكاشف.

```swift
func reset()
```

### Properties

```swift
var isAnomalyDetected: Bool       // هل تم الكشف عن تشويش حالياً
var consecutiveAnomalyCount: Int  // عدد التشويشات المتتالية
var currentMagnitude: Double      // آخر magnitude محسوب
var averageMagnitude: Double      // المتوسط المتحرك الحالي
var standardDeviation: Double     // الانحراف المعياري الحالي
var confidence: Double            // مستوى الثقة الحالي
```

## MagneticDeclinationCalculator

حاسبة الانحراف المغناطيسي.

### Static Methods

#### calculateDeclination(latitude:longitude:date:)
حساب الانحراف المغناطيسي.

```swift
static func calculateDeclination(latitude: Double,
                                 longitude: Double,
                                 date: Date = Date()) -> Double
```

**المعاملات:**
- `latitude`: خط العرض (بالدرجات)
- `longitude`: خط الطول (بالدرجات)
- `date`: التاريخ (افتراضي: التاريخ الحالي)

**الإرجاع:**
- `Double`: الانحراف المغناطيسي بالدرجات (موجب = شرق، سالب = غرب)

#### magneticToTrue(magneticHeading:latitude:longitude:)
تحويل heading من مغناطيسي إلى حقيقي.

```swift
static func magneticToTrue(magneticHeading: Double,
                          latitude: Double,
                          longitude: Double) -> Double
```

**المعاملات:**
- `magneticHeading`: الاتجاه المغناطيسي (بالدرجات)
- `latitude`: خط العرض
- `longitude`: خط الطول

**الإرجاع:**
- `Double`: الاتجاه الحقيقي (بالدرجات)

#### trueToMagnetic(trueHeading:latitude:longitude:)
تحويل heading من حقيقي إلى مغناطيسي.

```swift
static func trueToMagnetic(trueHeading: Double,
                           latitude: Double,
                           longitude: Double) -> Double
```

**المعاملات:**
- `trueHeading`: الاتجاه الحقيقي (بالدرجات)
- `latitude`: خط العرض
- `longitude`: خط الطول

**الإرجاع:**
- `Double`: الاتجاه المغناطيسي (بالدرجات)

#### estimateAccuracy(latitude:longitude:)
تقدير دقة حساب الانحراف.

```swift
static func estimateAccuracy(latitude: Double,
                             longitude: Double) -> Double
```

**المعاملات:**
- `latitude`: خط العرض
- `longitude`: خط الطول

**الإرجاع:**
- `Double`: دقة متوقعة بالدرجات (±)

## PerformanceMetricsCollector

جامع مقاييس الأداء.

### Public Methods

#### recordUpdateStart()
تسجيل بداية معالجة قراءة جديدة.

```swift
func recordUpdateStart() -> Date
```

**الإرجاع:**
- `Date`: timestamp البداية

#### recordUpdateEnd(startTime:)
تسجيل نهاية معالجة قراءة.

```swift
func recordUpdateEnd(startTime: Date)
```

**المعاملات:**
- `startTime`: timestamp البداية (من `recordUpdateStart()`)

#### recordFilterProcessing(time:)
تسجيل وقت معالجة فلتر Kalman.

```swift
func recordFilterProcessing(time: TimeInterval)
```

**المعاملات:**
- `time`: وقت المعالجة بالثواني

#### checkPerformanceBudgets()
التحقق من الالتزام بـ Performance Budgets.

```swift
func checkPerformanceBudgets() -> BudgetCheckResult
```

**الإرجاع:**
- `BudgetCheckResult`: نتيجة التحقق

#### printPerformanceReport()
طباعة تقرير الأداء.

```swift
func printPerformanceReport()
```

#### reset()
إعادة تعيين جميع القياسات.

```swift
func reset()
```

### Properties

```swift
var currentMetrics: Metrics  // المقاييس الحالية
```

### Metrics Structure

```swift
struct Metrics {
    var cpuUsage: Double              // CPU usage percentage
    var memoryUsage: Int64             // Memory usage in bytes
    var averageLatency: TimeInterval   // Average processing latency
    var maxLatency: TimeInterval      // Maximum latency
    var updateRate: Double             // Actual update rate (Hz)
    var droppedFrames: Int             // Number of dropped frames
    var filterProcessingTime: TimeInterval  // Kalman filter processing time
    
    var formattedMemoryUsage: String  // Memory formatted (e.g., "5.23 MB")
    var formattedCPUUsage: String     // CPU formatted (e.g., "3.5%")
}
```

## AdaptiveUpdateRateManager

مدير معدل التحديث التكيفي.

### Initialization

```swift
init()
```

### Public Methods

#### update(heading:timestamp:)
تحديث حالة الحركة بناءً على قراءة جديدة.

```swift
func update(heading: Double, 
            timestamp: Date = Date()) -> MotionState
```

**المعاملات:**
- `heading`: الاتجاه الحالي (بالدرجات)
- `timestamp`: timestamp القراءة (افتراضي: الآن)

**الإرجاع:**
- `MotionState`: حالة الحركة الحالية

#### shouldUpdate(timestamp:)
التحقق من إمكانية التحديث بناءً على Throttling.

```swift
func shouldUpdate(timestamp: Date = Date()) -> Bool
```

**المعاملات:**
- `timestamp`: timestamp الحالي (افتراضي: الآن)

**الإرجاع:**
- `Bool`: هل يجب التحديث

#### reset()
إعادة تعيين الحالة.

```swift
func reset()
```

### Properties

```swift
var currentUpdateInterval: TimeInterval  // معدل التحديث الحالي
var motionState: MotionState            // حالة الحركة الحالية
var onStateChanged: ((MotionState) -> Void)?  // Callback عند تغيير الحالة
var onUpdateRateChanged: ((TimeInterval) -> Void)?  // Callback عند تغيير المعدل
```

### MotionState Enum

```swift
enum MotionState {
    case stationary      // ثابت - 5 Hz
    case slowMovement    // حركة بطيئة - 15 Hz
    case fastMovement    // حركة سريعة - 30 Hz
    
    var updateInterval: TimeInterval  // معدل التحديث
    var description: String           // وصف الحالة
}
```

## QiblaCalculator

حاسبة اتجاه القبلة.

### Static Properties

```swift
static let kaabaLatitude: Double = 21.422487
static let kaabaLongitude: Double = 39.826206
```

### Static Methods

#### calculateQiblaDirection(from:)
حساب اتجاه القبلة من موقع معين.

```swift
static func calculateQiblaDirection(from latitude: Double, 
                                    longitude: Double) -> Double
```

**المعاملات:**
- `latitude`: خط العرض للموقع الحالي
- `longitude`: خط الطول للموقع الحالي

**الإرجاع:**
- `Double`: اتجاه القبلة بالدرجات (0-360، حيث 0 = الشمال)

#### calculateDistanceToKaaba(from:)
حساب المسافة إلى الكعبة بالكيلومترات.

```swift
static func calculateDistanceToKaaba(from latitude: Double, 
                                      longitude: Double) -> Double
```

**المعاملات:**
- `latitude`: خط العرض للموقع الحالي
- `longitude`: خط الطول للموقع الحالي

**الإرجاع:**
- `Double`: المسافة بالكيلومترات

#### calculateArrowRotation(qiblaDirection:deviceHeading:)
حساب زاوية دوران السهم للإشارة إلى القبلة.

```swift
static func calculateArrowRotation(qiblaDirection: Double, 
                                   deviceHeading: Double) -> Double
```

**المعاملات:**
- `qiblaDirection`: اتجاه القبلة (من `calculateQiblaDirection`)
- `deviceHeading`: اتجاه الجهاز الحالي (من البوصلة)

**الإرجاع:**
- `Double`: زاوية دوران السهم (بالدرجات)

## المراجع

- [Usage Examples](./examples.md)
- [Configuration Guide](./configuration.md)
- [Architecture Overview](../architecture/overview.md)
