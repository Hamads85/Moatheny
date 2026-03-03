# ADR-001: Compass Architecture Refactoring

**الحالة:** Proposed  
**التاريخ:** 30 يناير 2026  
**المؤلفون:** Architecture Reviewer

---

## السياق

بعد إضافة المكونات المتقدمة للبوصلة (Extended Kalman Filter، Magnetic Anomaly Detector، إلخ)، أصبح `CompassService` كبيراً ومعقداً (875+ سطر) ويحتوي على مسؤوليات متعددة. هذا يسبب:

1. صعوبة في الصيانة
2. صعوبة في الاختبار
3. صعوبة في التوسع
4. انتهاك مبادئ SOLID

## القرار

نقرر إعادة هيكلة `CompassService` إلى بنية معمارية أفضل تستخدم:

1. **Clean Architecture Layers**
   - Domain Layer: منطق العمل النقي
   - Data Layer: إدارة المستشعرات
   - Presentation Layer: UI updates فقط

2. **Dependency Injection**
   - استخدام Protocols للواجهات
   - تمرير Dependencies عبر Constructor
   - إنشاء Factory للبناء

3. **Separation of Concerns**
   - فصل كل مسؤولية إلى class منفصل
   - استخدام Composition بدلاً من Monolithic Class

## البدائل المدروسة

### البديل 1: إبقاء الوضع الحالي
**السلبيات:**
- صعوبة الصيانة
- صعوبة الاختبار
- انتهاك SOLID

**الإيجابيات:**
- لا يحتاج تغييرات فورية

### البديل 2: إعادة هيكلة كاملة
**السلبيات:**
- يحتاج وقت أطول
- قد يسبب regressions

**الإيجابيات:**
- بنية أفضل
- أسهل في الصيانة
- أسهل في الاختبار

**القرار:** البديل 2 (إعادة هيكلة تدريجية)

## العواقب

### الإيجابية
- ✅ بنية معمارية أفضل
- ✅ أسهل في الصيانة
- ✅ أسهل في الاختبار
- ✅ أسهل في التوسع
- ✅ يتبع SOLID Principles

### السلبية
- ⚠️ يحتاج وقت للتنفيذ
- ⚠️ قد يسبب regressions مؤقتة
- ⚠️ يحتاج إعادة كتابة بعض الاختبارات

## التنفيذ المقترح

### المرحلة 1: إنشاء Protocols
```swift
protocol KalmanFilterProtocol {
    func update(magneticHeading: Double, gyroRate: Double?, timestamp: TimeInterval) -> Double
    func reset()
}

protocol AnomalyDetectorProtocol {
    func analyze(magneticField: CMMagneticField, timestamp: TimeInterval) -> (weight: Double, isAnomaly: Bool)
    func reset()
}

protocol DeclinationCalculatorProtocol {
    func calculateDeclination(latitude: Double, longitude: Double) -> Double
    func magneticToTrue(magneticHeading: Double, latitude: Double, longitude: Double) -> Double
}
```

### المرحلة 2: فصل المكونات
```swift
// Domain Layer
class CompassDomainService {
    func calculateHeading(rawHeading: Double, filters: [FilterProtocol]) -> Double
}

// Data Layer
class CompassDataProvider {
    func startUpdating()
    func stopUpdating()
    var headingPublisher: AnyPublisher<Double, Never>
}

// Presentation Layer
class CompassService: ObservableObject {
    @Published var heading: Double = 0
    private let domainService: CompassDomainService
    private let dataProvider: CompassDataProvider
}
```

### المرحلة 3: إنشاء Factory
```swift
class CompassServiceFactory {
    static func create() -> CompassService {
        let ekf = ExtendedKalmanFilter(...)
        let detector = MagneticAnomalyDetector(...)
        let calculator = MagneticDeclinationCalculator()
        
        let domainService = CompassDomainService(
            ekf: ekf,
            detector: detector,
            calculator: calculator
        )
        
        let dataProvider = CompassDataProvider()
        
        return CompassService(
            domainService: domainService,
            dataProvider: dataProvider
        )
    }
}
```

## المراجع

- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [SOLID Principles](https://en.wikipedia.org/wiki/SOLID)
- [Dependency Injection](https://en.wikipedia.org/wiki/Dependency_injection)
