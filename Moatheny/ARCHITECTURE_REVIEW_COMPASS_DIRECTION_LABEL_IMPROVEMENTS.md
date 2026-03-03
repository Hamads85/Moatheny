# CompassDirectionLabel - الكود المحسن المقترح

هذا الملف يحتوي على الكود المحسن المقترح بناءً على المراجعة المعمارية.

---

## 1. إنشاء Angle Normalization Utility

### الخطوة 1: إضافة Extension على Double

**الملف:** `Moatheny/Moatheny/Utilities.swift` (أو إنشاء `AngleUtils.swift`)

```swift
import Foundation

extension Double {
    /// تطبيع زاوية إلى [0, 360) بالدرجات
    /// - Returns: زاوية مطبعة بين 0 و 360
    /// - Example: `(-45).normalizedAngleDegrees()` returns `315`
    func normalizedAngleDegrees() -> Double {
        var normalized = self.truncatingRemainder(dividingBy: 360)
        if normalized < 0 {
            normalized += 360
        }
        return normalized
    }
    
    /// تطبيع زاوية إلى [0, 2π) بالراديان
    /// - Returns: زاوية مطبعة بين 0 و 2π
    func normalizedAngleRadians() -> Double {
        var normalized = self
        while normalized < 0 {
            normalized += 2 * .pi
        }
        while normalized >= 2 * .pi {
            normalized -= 2 * .pi
        }
        return normalized
    }
    
    /// حساب الفرق الزاوي مع مراعاة الدائرية (للدرجات)
    /// - Parameter other: الزاوية الأخرى
    /// - Returns: الفرق الزاوي في النطاق [-180, 180]
    func angleDifferenceDegrees(to other: Double) -> Double {
        var diff = other - self
        diff = diff.truncatingRemainder(dividingBy: 360)
        if diff > 180 {
            diff -= 360
        } else if diff < -180 {
            diff += 360
        }
        return diff
    }
    
    /// حساب الفرق الزاوي مع مراعاة الدائرية (للراديان)
    /// - Parameter other: الزاوية الأخرى
    /// - Returns: الفرق الزاوي في النطاق [-π, π]
    func angleDifferenceRadians(to other: Double) -> Double {
        var diff = other - self
        diff = diff.truncatingRemainder(dividingBy: 2 * .pi)
        if diff > .pi {
            diff -= 2 * .pi
        } else if diff < -.pi {
            diff += 2 * .pi
        }
        return diff
    }
}
```

---

## 2. إنشاء CompassConfiguration

**الملف:** `Moatheny/Moatheny/CompassConfiguration.swift`

```swift
import Foundation
import SwiftUI

/// إعدادات البوصلة المركزية
/// Single Source of Truth لجميع القيم الثابتة المتعلقة بالبوصلة
struct CompassConfiguration {
    /// نصف قطر البوصلة (نصف القطر)
    static let compassRadius: CGFloat = 150
    
    /// قطر البوصلة الكامل
    static let compassDiameter: CGFloat = 300
    
    /// تحويل من نظام البوصلة (0° = شمال) إلى نظام الإحداثيات (0° = شرق)
    static let compassToCoordinateOffset: Double = 90
    
    /// الحد الأدنى للزاوية للتحقق من التوجه للقبلة (بالدرجات)
    static let qiblaPointingThreshold: Double = 7
    
    /// الحد الأقصى للدقة المقبولة (بالدرجات)
    static let maxAcceptableAccuracy: Double = 15
    
    /// الحد الأقصى لميلان الجهاز للقراءة الصحيحة (بالدرجات)
    static let maxPitchForReading: Double = 60
}
```

---

## 3. CompassDirectionLabel المحسن

**الملف:** `Moatheny/Moatheny/Views.swift`

```swift
// MARK: - Compass Direction Label (اسم الاتجاه الكامل)
struct CompassDirectionLabel: View {
    let text: String
    let baseAngle: Double // الزاوية الأساسية (0 للشمال، 90 للشرق، إلخ)
    let deviceHeading: Double // اتجاه الجهاز
    let color: Color
    let radius: CGFloat
    
    /// حساب الزاوية المعدلة مع التطبيع
    /// - baseAngle: زاوية الاتجاه في نظام البوصلة (0=شمال، 90=شرق، 180=جنوب، 270=غرب)
    /// - deviceHeading: اتجاه الجهاز في نظام البوصلة
    /// - adjustedAngle: الزاوية النسبية بعد تعويض دوران الجهاز (مطبعة بين 0-360)
    private var adjustedAngle: Double {
        guard baseAngle.isFinite, deviceHeading.isFinite else {
            return 0
        }
        return (baseAngle - deviceHeading).normalizedAngleDegrees()
    }
    
    /// تحويل الزاوية إلى راديان مع التحويل من نظام البوصلة إلى نظام الإحداثيات
    private var radians: Double {
        (CompassConfiguration.compassToCoordinateOffset - adjustedAngle) * .pi / 180
    }
    
    /// حساب موضع X على محيط الدائرة
    private var positionX: CGFloat {
        guard radius.isFinite, radius > 0, radians.isFinite else {
            return 0
        }
        return cos(radians) * radius
    }
    
    /// حساب موضع Y على محيط الدائرة
    private var positionY: CGFloat {
        guard radius.isFinite, radius > 0, radians.isFinite else {
            return 0
        }
        // في SwiftUI: y يزيد للأسفل (وليس للأعلى كما في الرياضيات)
        // لذلك نعكس إشارة y
        return -sin(radians) * radius
    }
    
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.6))
            .cornerRadius(8)
            .position(
                x: CompassConfiguration.compassRadius + positionX,
                y: CompassConfiguration.compassRadius + positionY
            )
    }
}
```

---

## 4. تحديث QiblaView

**الملف:** `Moatheny/Moatheny/Views.swift`

```swift
struct QiblaView: View {
    // ... existing code ...
    
    // تطبيع الزاوية بين 0 و 360
    private func normalizeAngle(_ angle: Double) -> Double {
        angle.normalizedAngleDegrees()
    }
    
    // هل الجهاز موجه للقبلة (±7 درجات) مع شرط دقة/معايرة جيدة
    var isPointingToQibla: Bool {
        let diff = abs(compass.heading.angleDifferenceDegrees(to: qiblaDirection))
        let pointing = diff < CompassConfiguration.qiblaPointingThreshold || 
                      diff > (360 - CompassConfiguration.qiblaPointingThreshold)
        let accuracyOk = (compass.accuracy < 0) || 
                        (compass.accuracy <= CompassConfiguration.maxAcceptableAccuracy)
        return pointing && accuracyOk && !compass.calibrationNeeded
    }
    
    // هل الجهاز في وضعية صحيحة للقراءة
    var isDeviceReady: Bool {
        return compass.isDeviceFlat || abs(compass.pitch) < CompassConfiguration.maxPitchForReading
    }
    
    // ... rest of code ...
}
```

---

## 5. تحديث QiblaCalculator

**الملف:** `Moatheny/Moatheny/CompassService.swift`

```swift
struct QiblaCalculator {
    // ... existing code ...
    
    /// حساب اتجاه القبلة من موقع معين
    static func calculateQiblaDirection(from latitude: Double, longitude: Double) -> Double {
        // ... existing calculation code ...
        
        // تطبيع الزاوية لتكون بين 0 و 360
        return bearing.normalizedAngleDegrees()
    }
    
    /// حساب زاوية دوران السهم
    static func calculateArrowRotation(qiblaDirection: Double, deviceHeading: Double) -> Double {
        // حساب الفرق بين اتجاه القبلة واتجاه الجهاز
        // استخدام angleDifferenceDegrees للحصول على أقصر مسار للدوران
        return deviceHeading.angleDifferenceDegrees(to: qiblaDirection)
    }
}
```

---

## 6. تحديث ExtendedKalmanFilter

**الملف:** `Moatheny/Moatheny/ExtendedKalmanFilter.swift`

```swift
final class ExtendedKalmanFilter {
    // ... existing code ...
    
    /// تطبيع زاوية إلى [0, 2π)
    private func normalizeAngle(_ angle: Double) -> Double {
        angle.normalizedAngleRadians()
    }
    
    /// حساب الفرق الزاوي مع مراعاة الدائرية
    private func normalizeAngleDifference(_ diff: Double) -> Double {
        // يمكن استخدام angleDifferenceRadians إذا كان لدينا زاويتين
        // هنا نحتاج فقط تطبيع الفرق
        var normalized = diff
        while normalized > .pi {
            normalized -= 2 * .pi
        }
        while normalized < -.pi {
            normalized += 2 * .pi
        }
        return normalized
    }
}
```

---

## 7. Unit Tests

**الملف:** `Moatheny/AngleUtilsTests.swift`

```swift
import XCTest
@testable import Moatheny

final class AngleUtilsTests: XCTestCase {
    
    func testNormalizedAngleDegrees_PositiveAngle() {
        XCTAssertEqual(45.0.normalizedAngleDegrees(), 45.0, accuracy: 0.001)
        XCTAssertEqual(360.0.normalizedAngleDegrees(), 0.0, accuracy: 0.001)
        XCTAssertEqual(720.0.normalizedAngleDegrees(), 0.0, accuracy: 0.001)
    }
    
    func testNormalizedAngleDegrees_NegativeAngle() {
        XCTAssertEqual((-45.0).normalizedAngleDegrees(), 315.0, accuracy: 0.001)
        XCTAssertEqual((-360.0).normalizedAngleDegrees(), 0.0, accuracy: 0.001)
        XCTAssertEqual((-720.0).normalizedAngleDegrees(), 0.0, accuracy: 0.001)
    }
    
    func testNormalizedAngleDegrees_LargeAngles() {
        XCTAssertEqual(450.0.normalizedAngleDegrees(), 90.0, accuracy: 0.001)
        XCTAssertEqual((-450.0).normalizedAngleDegrees(), 270.0, accuracy: 0.001)
    }
    
    func testAngleDifferenceDegrees_ShortPath() {
        XCTAssertEqual(10.0.angleDifferenceDegrees(to: 20.0), 10.0, accuracy: 0.001)
        XCTAssertEqual(350.0.angleDifferenceDegrees(to: 10.0), 20.0, accuracy: 0.001)
        XCTAssertEqual(10.0.angleDifferenceDegrees(to: 350.0), -20.0, accuracy: 0.001)
    }
    
    func testAngleDifferenceDegrees_CrossZero() {
        XCTAssertEqual(359.0.angleDifferenceDegrees(to: 1.0), 2.0, accuracy: 0.001)
        XCTAssertEqual(1.0.angleDifferenceDegrees(to: 359.0), -2.0, accuracy: 0.001)
    }
    
    func testNormalizedAngleRadians() {
        XCTAssertEqual((.pi).normalizedAngleRadians(), .pi, accuracy: 0.001)
        XCTAssertEqual((-.pi).normalizedAngleRadians(), .pi, accuracy: 0.001)
        XCTAssertEqual((2 * .pi).normalizedAngleRadians(), 0.0, accuracy: 0.001)
    }
}
```

---

## 8. Migration Checklist

### المرحلة 1: إضافة Utilities
- [ ] إضافة `normalizedAngleDegrees()` إلى `Double` extension
- [ ] إضافة `normalizedAngleRadians()` إلى `Double` extension
- [ ] إضافة `angleDifferenceDegrees()` و `angleDifferenceRadians()`
- [ ] كتابة Unit Tests

### المرحلة 2: إنشاء Configuration
- [ ] إنشاء `CompassConfiguration`
- [ ] نقل جميع القيم الثابتة إلى Configuration

### المرحلة 3: تحديث CompassDirectionLabel
- [ ] استخدام `normalizedAngleDegrees()` في `adjustedAngle`
- [ ] استخدام `CompassConfiguration.compassRadius`
- [ ] إضافة input validation
- [ ] إزالة تكرار حساب `radians`

### المرحلة 4: تحديث المكونات الأخرى
- [ ] تحديث `QiblaView.normalizeAngle()`
- [ ] تحديث `QiblaCalculator.calculateQiblaDirection()`
- [ ] تحديث `QiblaCalculator.calculateArrowRotation()`
- [ ] تحديث `ExtendedKalmanFilter.normalizeAngle()`

### المرحلة 5: الاختبار
- [ ] تشغيل Unit Tests
- [ ] اختبار يدوي للبوصلة
- [ ] التحقق من عدم وجود regressions

---

## 9. Benefits Summary

### قبل التحسين
- ❌ منطق تطبيع الزاوية مكرر في 3+ أماكن
- ❌ قيم hard-coded في الكود
- ❌ حساب `radians` مكرر
- ❌ لا يوجد input validation

### بعد التحسين
- ✅ منطق تطبيع الزاوية في مكان واحد (DRY)
- ✅ قيم ثابتة في Configuration (Single Source of Truth)
- ✅ حساب `radians` مرة واحدة فقط
- ✅ input validation شامل
- ✅ أسهل في الصيانة والتوسع
- ✅ قابل للاختبار بشكل أفضل

---

**تاريخ الإنشاء:** 30 يناير 2026  
**الإصدار:** 1.0
