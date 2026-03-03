# Contribution Guidelines - Compass System

## نظرة عامة

شكراً لاهتمامك بالمساهمة في تطوير نظام البوصلة! هذا الدليل يوضح كيفية المساهمة بشكل فعال.

## عملية المساهمة

### 1. Fork المشروع

1. اذهب إلى [المستودع](https://github.com/your-org/moatheny)
2. اضغط **Fork**
3. Clone الـ Fork:

```bash
git clone https://github.com/your-username/moatheny.git
cd moatheny
```

### 2. إنشاء Branch

```bash
git checkout -b feature/your-feature-name
# أو
git checkout -b fix/your-bug-fix
```

**أسماء Branches:**
- `feature/`: ميزة جديدة
- `fix/`: إصلاح خطأ
- `docs/`: تحديث الوثائق
- `refactor/`: إعادة هيكلة الكود
- `test/`: إضافة/تحسين الاختبارات

### 3. التطوير

#### اتبع Coding Standards

- استخدم Swift Style Guide
- اكتب كود واضح وموثق
- اتبع SOLID Principles
- استخدم meaningful names

#### اكتب Tests

```swift
// مثال: Test جديد
func testExtendedKalmanFilter() {
    let ekf = ExtendedKalmanFilter()
    
    // Test initialization
    XCTAssertFalse(ekf.isInitialized)
    
    // Test update
    let measurement = SensorMeasurement(...)
    let state = ekf.update(measurement: measurement)
    
    XCTAssertTrue(ekf.isInitialized)
    XCTAssertNotNil(state)
}
```

#### وثّق الكود

```swift
/// Extended Kalman Filter للبوصلة
///
/// يستخدم هذا الفلتر لتنعيم قراءات البوصلة ودمج المستشعرات.
/// - Parameters:
///   - processNoise: ضوضاء العملية (افتراضي: 0.01)
///   - measurementNoise: ضوضاء القياس (افتراضي: 0.1)
final class ExtendedKalmanFilter {
    // ...
}
```

### 4. Commit

```bash
git add .
git commit -m "feat: إضافة ميزة جديدة"
```

**Commit Message Format:**
```
<type>: <subject>

<body>

<footer>
```

**Types:**
- `feat`: ميزة جديدة
- `fix`: إصلاح خطأ
- `docs`: تحديث الوثائق
- `style`: تغييرات التنسيق
- `refactor`: إعادة هيكلة
- `test`: إضافة/تحسين الاختبارات
- `chore`: مهام الصيانة

**أمثلة:**
```
feat: إضافة Adaptive Update Rate Manager

يضيف Adaptive Update Rate Manager لتعديل معدل التحديث
تلقائياً بناءً على حالة الحركة.

Closes #123
```

```
fix: إصلاح مشكلة في حساب الانحراف المغناطيسي

كان حساب الانحراف يعطي قيماً خاطئة في بعض المناطق.
تم إصلاحه باستخدام WMM الصحيح.

Fixes #456
```

### 5. Push

```bash
git push origin feature/your-feature-name
```

### 6. إنشاء Pull Request

1. اذهب إلى المستودع الأصلي
2. اضغط **New Pull Request**
3. املأ الوصف:
   - ما الذي تغير؟
   - لماذا؟
   - كيف تم الاختبار؟
4. اضغط **Create Pull Request**

## Coding Standards

### Swift Style

```swift
// ✅ جيد
final class CompassService: NSObject, ObservableObject {
    @Published var heading: Double = 0
    
    private let locationManager = CLLocationManager()
    
    func startUpdating() {
        // ...
    }
}

// ❌ سيء
class compass_service {
    var Heading:Double=0
    let location_manager=CLLocationManager()
    func StartUpdating(){
        // ...
    }
}
```

### Naming

- **Classes**: PascalCase (`CompassService`)
- **Functions**: camelCase (`startUpdating()`)
- **Variables**: camelCase (`heading`)
- **Constants**: camelCase (`optimalHeadingFilter`)
- **Enums**: PascalCase (`MotionState`)

### Documentation

```swift
/// وصف مختصر
///
/// وصف تفصيلي إذا لزم.
///
/// - Parameters:
///   - heading: الاتجاه بالدرجات (0-360)
///   - timestamp: timestamp القراءة
/// - Returns: الاتجاه المنعم بالدرجات
/// - Throws: `CompassError` إذا فشلت المعالجة
func processHeading(_ heading: Double, timestamp: TimeInterval) throws -> Double {
    // ...
}
```

### Error Handling

```swift
// ✅ جيد
do {
    let result = try processHeading(heading)
    return result
} catch CompassError.calibrationNeeded {
    // Handle calibration
} catch {
    // Handle other errors
}

// ❌ سيء
let result = processHeading(heading)!  // Force unwrap
```

## Testing

### كتابة Tests

```swift
import XCTest
@testable import Moatheny

final class ExtendedKalmanFilterTests: XCTestCase {
    var ekf: ExtendedKalmanFilter!
    
    override func setUp() {
        super.setUp()
        ekf = ExtendedKalmanFilter()
    }
    
    override func tearDown() {
        ekf = nil
        super.tearDown()
    }
    
    func testInitialization() {
        XCTAssertFalse(ekf.isInitialized)
        XCTAssertNotNil(ekf.state)
    }
    
    func testUpdate() {
        let measurement = SensorMeasurement(
            type: .magnetometer,
            timestamp: Date().timeIntervalSince1970
        )
        measurement.magneticField = CMMagneticField(x: 1, y: 0, z: 0)
        
        let state = ekf.update(measurement: measurement)
        
        XCTAssertTrue(ekf.isInitialized)
        XCTAssertNotNil(state)
    }
}
```

### تشغيل Tests

```bash
# جميع Tests
xcodebuild test -scheme Moatheny

# Test محدد
xcodebuild test -scheme Moatheny -only-testing:MoathenyTests/ExtendedKalmanFilterTests
```

## Code Review

### قبل إرسال PR

- [ ] الكود يتبع Coding Standards
- [ ] جميع Tests تمر
- [ ] تم إضافة Tests للكود الجديد
- [ ] الكود موثق
- [ ] لا توجد Warnings
- [ ] Performance ضمن Budgets

### Review Checklist

- [ ] الكود واضح وسهل القراءة
- [ ] لا توجد Code Smells
- [ ] الأداء جيد
- [ ] الأمان محفوظ
- [ ] التوافق مع iOS 16+

## المساهمة في الوثائق

### تحديث الوثائق

عند إضافة ميزة جديدة:
1. حدّث [API Documentation](../api/interfaces.md)
2. أضف أمثلة في [Usage Examples](../api/examples.md)
3. حدّث [Configuration Guide](../api/configuration.md) إذا لزم
4. أضف ADR إذا كان قراراً معمارياً مهماً

### كتابة ADR

عند اتخاذ قرار معماري مهم:
1. استخدم [ADR Template](../adr/template.md)
2. املأ جميع الأقسام
3. أضف المراجع

## الأسئلة الشائعة

### Q: كيف أبدأ؟

A: ابدأ بـ:
1. قراءة [Setup Instructions](./setup.md)
2. استكشاف الكود الموجود
3. اختيار Issue بسيط للبدء

### Q: كيف أختار ما أعمل عليه?

A: راجع:
- Issues المفتوحة
- [Architecture Action Items](../../ARCHITECTURE_ACTION_ITEMS.md)
- [Technical Debt Assessment](../../TECHNICAL_DEBT_ASSESSMENT.md)

### Q: ماذا لو كان لدي سؤال?

A: افتح Issue أو اسأل في Discussions.

## المراجع

- [Setup Instructions](./setup.md)
- [Testing Guide](./testing.md)
- [Coding Standards](../reference/standards.md)
- [API Documentation](../api/interfaces.md)
