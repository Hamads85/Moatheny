# معمارية نظام البوصلة المحسنة - Enhanced Compass Architecture

## 📋 نظرة عامة

هذا المستند يصف المعمارية المحسنة لنظام البوصلة في تطبيق Moatheny، والتي تتضمن:
- **Extended Kalman Filter (EKF)** للدمج المتقدم بين المستشعرات
- **نظام كشف التشويش المغناطيسي** (Magnetic Interference Detection)
- **تعويض الانحراف المغناطيسي** (Magnetic Declination Compensation)
- **Sensor Fusion متقدم** (Accelerometer + Gyroscope + Magnetometer)

---

## 🏗️ المعمارية المقترحة

### 1. هيكل الطبقات (Layer Architecture)

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         CompassViewModel (ObservableObject)         │  │
│  │  - heading: Double                                   │  │
│  │  - accuracy: Double                                 │  │
│  │  - calibrationStatus: CalibrationStatus             │  │
│  │  - interferenceLevel: InterferenceLevel             │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                         │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         CompassService (Orchestrator)                 │  │
│  │  - Coordinates sensor fusion                         │  │
│  │  - Manages calibration                               │  │
│  │  - Publishes unified heading                         │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Domain Layer                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │   Sensor     │  │   Filter     │  │ Interference │    │
│  │  Protocols   │  │  Protocols   │  │   Detector   │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Magnetic Declination Service                  │  │
│  │  - Calculates magnetic declination                   │  │
│  │  - Updates based on location                         │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       Data Layer                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │   Core       │  │   Core       │  │   Core       │    │
│  │  Location    │  │  Motion      │  │  Location    │    │
│  │  Manager     │  │  Manager     │  │  (Declination)│   │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔧 المكونات الرئيسية

### 1. Extended Kalman Filter (EKF)

#### الوصف
فلتر Kalman الموسع للتعامل مع الحالة ثلاثية الأبعاد (Roll, Pitch, Yaw) والدمج بين المستشعرات المتعددة.

#### الحالة (State Vector)
```swift
State = [roll, pitch, yaw, roll_rate, pitch_rate, yaw_rate]
```

#### القياسات (Measurements)
- **Accelerometer**: Roll, Pitch (عندما يكون الجهاز ثابتاً)
- **Gyroscope**: Roll rate, Pitch rate, Yaw rate
- **Magnetometer**: Yaw (heading) مع تعويض Roll/Pitch
- **CoreLocation Heading**: Heading مباشر (fallback)

#### المزايا
- ✅ دمج متعدد المستشعرات
- ✅ تعويض تلقائي للانحراف المغناطيسي
- ✅ معالجة أفضل للانتقالات الزاوية (359° → 0°)
- ✅ تقدير ديناميكي للضوضاء

---

### 2. نظام كشف التشويش المغناطيسي (Magnetic Interference Detector)

#### الوصف
يكشف وجود مصادر مغناطيسية خارجية تؤثر على دقة البوصلة.

#### المؤشرات (Indicators)
1. **قوة المجال المغناطيسي** (Magnetic Field Strength)
   - القيمة الطبيعية: ~20-60 μT
   - تشويش محتمل: < 10 μT أو > 100 μT

2. **اتساق الاتجاه** (Heading Consistency)
   - تباين كبير في القراءات = تشويش محتمل

3. **مقارنة مع Gyroscope**
   - اختلاف كبير بين Magnetometer و Gyroscope = تشويش

4. **مقارنة مع CoreLocation**
   - اختلاف كبير بين مصادر متعددة = تشويش

#### مستويات التشويش
```swift
enum InterferenceLevel {
    case none          // لا يوجد تشويش
    case low           // تشويش بسيط (دقة مقبولة)
    case medium        // تشويش متوسط (تحذير)
    case high          // تشويش عالي (دقة منخفضة)
    case critical      // تشويش حرج (غير موثوق)
}
```

---

### 3. نظام تعويض الانحراف المغناطيسي (Magnetic Declination Service)

#### الوصف
يحسب ويعوض الانحراف المغناطيسي بناءً على الموقع الجغرافي.

#### المصادر
1. **World Magnetic Model (WMM)**
   - نموذج عالمي محدث سنوياً
   - دقة عالية في معظم المناطق

2. **IGRF (International Geomagnetic Reference Field)**
   - نموذج بديل أكثر دقة في بعض المناطق

#### الحساب
```swift
True Heading = Magnetic Heading + Declination
```

#### التحديث
- يتم تحديث الانحراف عند تغيير الموقع
- يتم تخزين القيمة مؤقتاً لتقليل الحسابات

---

### 4. Sensor Fusion Engine

#### الوصف
يدمج البيانات من المستشعرات المتعددة للحصول على قراءة دقيقة.

#### المستشعرات المستخدمة

##### Accelerometer
- **الاستخدام**: Roll, Pitch (عندما يكون الجهاز ثابتاً)
- **الدقة**: عالية للاتجاهات الثابتة
- **القيود**: يتأثر بالتسارع الخطي

##### Gyroscope
- **الاستخدام**: معدل الدوران (angular rates)
- **الدقة**: ممتازة للحركات السريعة
- **القيود**: drift مع مرور الوقت

##### Magnetometer
- **الاستخدام**: Heading (مع تعويض Roll/Pitch)
- **الدقة**: جيدة في غياب التشويش
- **القيود**: يتأثر بالمجالات المغناطيسية الخارجية

##### CoreLocation Heading
- **الاستخدام**: Heading مباشر (fallback/validation)
- **الدقة**: جيدة عندما يكون متاحاً
- **القيود**: يتطلب GPS وموقع دقيق

#### استراتيجية الدمج
1. **عندما يكون الجهاز ثابتاً**: استخدام Accelerometer + Magnetometer
2. **عند الحركة**: استخدام Gyroscope مع تصحيح من Magnetometer
3. **عند وجود تشويش**: الاعتماد على Gyroscope مع تصحيح drift
4. **التحقق**: مقارنة مع CoreLocation Heading عند توافره

---

## 📐 البروتوكولات (Protocols)

### 1. Sensor Data Provider Protocol

```swift
protocol SensorDataProvider {
    var isAvailable: Bool { get }
    var updateInterval: TimeInterval { get set }
    
    func startUpdates() throws
    func stopUpdates()
}

protocol AccelerometerProvider: SensorDataProvider {
    var acceleration: CMAcceleration { get }
    var timestamp: TimeInterval { get }
}

protocol GyroscopeProvider: SensorDataProvider {
    var rotationRate: CMRotationRate { get }
    var timestamp: TimeInterval { get }
}

protocol MagnetometerProvider: SensorDataProvider {
    var magneticField: CMMagneticField { get }
    var timestamp: TimeInterval { get }
    var accuracy: CMMagneticFieldCalibrationAccuracy { get }
}
```

### 2. Filter Protocol

```swift
protocol Filter {
    associatedtype State
    associatedtype Measurement
    
    var state: State { get }
    var covariance: Matrix { get }
    
    func predict(dt: TimeInterval) -> State
    func update(measurement: Measurement) -> State
    func reset()
}
```

### 3. Interference Detector Protocol

```swift
protocol InterferenceDetector {
    func detect(magneticField: CMMagneticField, 
                heading: Double, 
                gyroRate: CMRotationRate) -> InterferenceLevel
    
    func reset()
}
```

### 4. Declination Service Protocol

```swift
protocol MagneticDeclinationService {
    func getDeclination(for location: CLLocationCoordinate2D) -> Double
    func getDeclination(for location: CLLocationCoordinate2D, 
                       completion: @escaping (Double) -> Void)
}
```

---

## 🔄 تدفق البيانات (Data Flow)

```
┌─────────────┐
│ Accelerometer│──┐
└─────────────┘  │
                 │
┌─────────────┐  │    ┌──────────────────┐
│  Gyroscope  │──┼───▶│  Sensor Fusion   │
└─────────────┘  │    │     Engine       │
                 │    └──────────────────┘
┌─────────────┐  │              │
│ Magnetometer│──┘              │
└─────────────┘                 ▼
                         ┌──────────────────┐
┌─────────────┐          │   Interference   │
│ CoreLocation│─────────▶│     Detector     │
│   Heading   │          └──────────────────┘
└─────────────┘                 │
                                ▼
                         ┌──────────────────┐
                         │   Extended       │
                         │  Kalman Filter   │
                         │      (EKF)       │
                         └──────────────────┘
                                │
                                ▼
                         ┌──────────────────┐
                         │  Declination      │
                         │   Correction     │
                         └──────────────────┘
                                │
                                ▼
                         ┌──────────────────┐
                         │  Final Heading    │
                         │    (0-360°)      │
                         └──────────────────┘
```

---

## 🎯 نقاط التكامل

### 1. التكامل مع CompassService الحالي

```swift
// CompassService سيتحول إلى Orchestrator
final class CompassService: NSObject, ObservableObject {
    // المكونات الجديدة
    private let ekfFilter: ExtendedKalmanFilter
    private let interferenceDetector: MagneticInterferenceDetector
    private let declinationService: MagneticDeclinationService
    private let sensorFusion: SensorFusionEngine
    
    // الواجهة الحالية تبقى كما هي للتوافق
    @Published var heading: Double = 0
    @Published var accuracy: Double = -1
    // ...
}
```

### 2. التكامل مع QiblaService

```swift
// QiblaService يستخدم CompassService.heading مباشرة
// لا حاجة لتغييرات هنا
```

### 3. التكامل مع LocationService

```swift
// LocationService يوفر الموقع لـ DeclinationService
// يتم الاشتراك في تحديثات الموقع
```

---

## 📊 مخطط UML

```
┌─────────────────────────────────────────────────────────────┐
│                    CompassService                           │
│  + heading: Double                                          │
│  + accuracy: Double                                         │
│  + interferenceLevel: InterferenceLevel                     │
│  + startUpdating()                                          │
│  + stopUpdating()                                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ uses
                              ▼
        ┌─────────────────────────────────────┐
        │    SensorFusionEngine               │
        │  + fuse(accel, gyro, mag)          │
        │  + getFusedHeading()                │
        └─────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Accelerometer│    │   Gyroscope  │    │ Magnetometer│
│   Provider   │    │   Provider   │    │   Provider   │
└──────────────┘    └──────────────┘    └──────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────┐
        │  ExtendedKalmanFilter               │
        │  + predict(dt)                      │
        │  + update(measurement)              │
        │  + reset()                           │
        └─────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Interference │    │  Declination │    │   Core       │
│   Detector   │    │   Service    │    │  Location    │
└──────────────┘    └──────────────┘    └──────────────┘
```

---

## 🔍 تفاصيل التطبيق

### 1. Extended Kalman Filter Implementation

#### State Vector (6D)
```swift
struct EKFState {
    var roll: Double      // Roll angle (rad)
    var pitch: Double     // Pitch angle (rad)
    var yaw: Double      // Yaw angle (rad)
    var rollRate: Double // Roll angular velocity (rad/s)
    var pitchRate: Double // Pitch angular velocity (rad/s)
    var yawRate: Double  // Yaw angular velocity (rad/s)
}
```

#### Process Model
```swift
// State transition: x_k = F * x_{k-1} + B * u_k + w_k
// F: State transition matrix
// B: Control input matrix
// w_k: Process noise
```

#### Measurement Model
```swift
// Measurement: z_k = H * x_k + v_k
// H: Measurement matrix
// v_k: Measurement noise
```

### 2. Magnetic Interference Detection Algorithm

```swift
func detectInterference(magneticField: CMMagneticField,
                       heading: Double,
                       gyroRate: CMRotationRate,
                       headingHistory: [Double]) -> InterferenceLevel {
    
    var score = 0.0
    
    // 1. Check magnetic field strength
    let fieldStrength = sqrt(
        pow(magneticField.x, 2) +
        pow(magneticField.y, 2) +
        pow(magneticField.z, 2)
    )
    
    if fieldStrength < 10 || fieldStrength > 100 {
        score += 2.0 // Strong indicator
    }
    
    // 2. Check heading consistency
    if headingHistory.count >= 5 {
        let variance = calculateVariance(headingHistory)
        if variance > 15.0 { // degrees
            score += 1.5
        }
    }
    
    // 3. Compare with gyroscope
    let expectedHeadingChange = gyroRate.z * dt
    let actualHeadingChange = heading - lastHeading
    let discrepancy = abs(expectedHeadingChange - actualHeadingChange)
    
    if discrepancy > 5.0 { // degrees
        score += 1.0
    }
    
    // Determine level
    switch score {
    case 0..<1: return .none
    case 1..<2: return .low
    case 2..<3: return .medium
    case 3..<4: return .high
    default: return .critical
    }
}
```

### 3. Magnetic Declination Calculation

```swift
// استخدام World Magnetic Model (WMM)
// أو API مثل: https://www.ngdc.noaa.gov/geomag-web/

func calculateDeclination(latitude: Double, 
                         longitude: Double,
                         date: Date) -> Double {
    // WMM calculation
    // أو API call
    // Returns declination in degrees
}
```

---

## 📈 التحسينات المتوقعة

### الدقة (Accuracy)
- **الحالي**: ±5-15 درجة (حسب الظروف)
- **المحسن**: ±2-5 درجة (في ظروف طبيعية)
- **مع تشويش**: ±5-10 درجة (مع كشف وتحذير)

### الاستقرار (Stability)
- **الحالي**: تذبذب ±2-3 درجة
- **المحسن**: تذبذب ±0.5-1 درجة

### الاستجابة (Responsiveness)
- **الحالي**: تأخير 0.5-1 ثانية
- **المحسن**: تأخير 0.2-0.5 ثانية

---

## 🚀 خطة التنفيذ

### المرحلة 1: الأساسيات
1. ✅ تصميم المعمارية (هذا المستند)
2. ⬜ إنشاء البروتوكولات الأساسية
3. ⬜ تطبيق Extended Kalman Filter الأساسي
4. ⬜ تطبيق Sensor Fusion Engine

### المرحلة 2: التحسينات
1. ⬜ تطبيق نظام كشف التشويش
2. ⬜ تطبيق نظام تعويض الانحراف المغناطيسي
3. ⬜ تحسين معاملات EKF
4. ⬜ اختبارات شاملة

### المرحلة 3: التكامل
1. ⬜ دمج المكونات الجديدة مع CompassService
2. ⬜ اختبار التوافق مع QiblaView
3. ⬜ تحسين الأداء
4. ⬜ توثيق API

---

## 📝 ملاحظات مهمة

### التوافق مع iOS
- ✅ CoreMotion متاح من iOS 4.0+
- ✅ CoreLocation متاح من iOS 2.0+
- ✅ CMAttitudeReferenceFrame متاح من iOS 5.0+

### الأداء
- EKF يعمل بتردد 30-60 Hz (حسب إعدادات المستشعرات)
- استهلاك البطارية: متوسط (مشابه للحالي)
- استخدام الذاكرة: منخفض (< 5 MB)

### الاختبار
- اختبارات وحدة لكل مكون
- اختبارات تكامل مع المستشعرات
- اختبارات في بيئات مختلفة (داخلية/خارجية)
- اختبارات مع أجهزة مختلفة

---

## 📚 المراجع

1. **Extended Kalman Filter**
   - "Estimation with Applications to Tracking and Navigation" - Bar-Shalom et al.
   - "Kalman Filtering: Theory and Practice" - Grewal & Andrews

2. **Sensor Fusion**
   - "A Tutorial on Attitude Representations" - Diebel
   - "An Introduction to Inertial Navigation" - Woodman

3. **Magnetic Declination**
   - World Magnetic Model: https://www.ngdc.noaa.gov/geomag/
   - IGRF: https://www.ngdc.noaa.gov/IAGA/vmod/igrf.html

4. **iOS CoreMotion**
   - Apple Developer Documentation: CoreMotion Framework

---

**تاريخ الإنشاء**: 2026-01-30  
**الإصدار**: 1.0  
**المؤلف**: Mobile Architecture Lead
