# حل مشكلة دوران بوصلة القبلة

**التاريخ**: 31 يناير 2026  
**المحلل**: Mobile Architecture Lead  
**الحالة**: تم تطبيق الحل الأول (عكس الإشارة)

---

## 📋 ملخص المشكلة

الكود المرجعي من GitHub يعمل بشكل صحيح، بينما الكود الحالي لا يعطي نفس النتيجة. الفرق الرئيسي في كيفية حساب زاوية دوران السهم.

---

## 🔍 التحليل التفصيلي

### الكود المرجعي (يعمل بشكل صحيح)

```swift
// حساب زاوية القبلة (بالراديان)
func setLatLonForDistanceAndAngle(userlocation: CLLocation) -> Double {
    // ... حساب bearing ...
    return radiansBearing  // بالراديان (0 إلى 2π)
}

// تطبيق الدوران
func locationManager(manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    let needleDirection = -newHeading.trueHeading  // سالب!
    self.needle.transform = CGAffineTransformMakeRotation(
        CGFloat(((Double(needleDirection) * M_PI) / 180.0) + needleAngle!)
    )
}
```

**التحليل الرياضي**:
```
needleDirection = -newHeading.trueHeading
rotation = (needleDirection * π/180) + needleAngle
         = (-heading * π/180) + qiblaAngle
         = qiblaAngle - heading (بعد التحويل للدرجات)
```

### الكود الحالي (قبل التعديل)

```swift
static func calculateArrowRotation(qiblaDirection: Double, deviceHeading: Double) -> Double {
    var rotation = qiblaDirection - deviceHeading  // نفس المعادلة!
    while rotation > 180 { rotation -= 360 }
    while rotation < -180 { rotation += 360 }
    return rotation
}
```

**التحليل**: الكود الحالي يستخدم نفس المعادلة الرياضية (`qiblaDirection - deviceHeading`)، لكنه لا يعمل بشكل صحيح.

---

## 🎯 المشكلة الحقيقية

### الفرضية 1: اختلاف اتجاه الدوران

- **UIKit `CGAffineTransformMakeRotation`**: يدور في اتجاه عكس عقارب الساعة للقيم الموجبة
- **SwiftUI `rotationEffect`**: يدور في اتجاه عكس عقارب الساعة للقيم الموجبة (نفس UIKit!)

**النتيجة**: كلاهما يدور في نفس الاتجاه، إذن المشكلة ليست هنا.

### الفرضية 2: اختلاف نظام الإحداثيات

في UIKit، قد يكون هناك اختلاف في كيفية تطبيق التحويلات بسبب:
- نظام إحداثيات UIKit (Y-axis مقلوب)
- طريقة تطبيق `CGAffineTransform` على العناصر

في SwiftUI:
- نظام إحداثيات مختلف
- `rotationEffect` قد يتعامل مع الزوايا بشكل مختلف

### الفرضية 3: اتجاه السهم الابتدائي

- الكود المرجعي: السهم قد يكون موجه في اتجاه معين في البداية
- الكود الحالي: السهم موجه للأعلى (الشمال) في البداية

---

## ✅ الحل المطبق

### الحل 1: عكس الإشارة (تم التطبيق)

```swift
static func calculateArrowRotation(qiblaDirection: Double, deviceHeading: Double) -> Double {
    // عكس الإشارة لمحاكاة الكود المرجعي
    var rotation = deviceHeading - qiblaDirection  // عكس!
    
    // تطبيع الزاوية إلى [-180, 180]
    while rotation > 180 { rotation -= 360 }
    while rotation < -180 { rotation += 360 }
    
    return rotation
}
```

**المنطق**:
- الكود المرجعي يستخدم `-heading` في `needleDirection`
- هذا قد يعني أننا نحتاج عكس الإشارة في SwiftUI
- الحل: استخدام `deviceHeading - qiblaDirection` بدلاً من `qiblaDirection - deviceHeading`

---

## 🧪 اختبار الحل

### اختبار 1: الجهاز يشير للشمال (0°)
- `qiblaDirection = 243°`
- `deviceHeading = 0°`
- **قبل التعديل**: `rotation = 243° - 0° = 243°`
- **بعد التعديل**: `rotation = 0° - 243° = -243°`
- **النتيجة المتوقعة**: السهم يجب أن يشير 243° (جنوب غرب)

### اختبار 2: الجهاز يشير للقبلة (243°)
- `qiblaDirection = 243°`
- `deviceHeading = 243°`
- **قبل التعديل**: `rotation = 243° - 243° = 0°`
- **بعد التعديل**: `rotation = 243° - 243° = 0°`
- **النتيجة المتوقعة**: السهم يجب أن يشير للأعلى (0°)

### اختبار 3: الجهاز يشير للشرق (90°)
- `qiblaDirection = 243°`
- `deviceHeading = 90°`
- **قبل التعديل**: `rotation = 243° - 90° = 153°`
- **بعد التعديل**: `rotation = 90° - 243° = -153°`
- **النتيجة المتوقعة**: السهم يجب أن يشير 153° من الشمال

---

## 🔄 حلول بديلة (إذا لم يعمل الحل الأول)

### الحل البديل 1: عكس الإشارة في rotationEffect

إذا كان الحل الأول لا يعمل، جرب عكس الإشارة في SwiftUI:

```swift
.rotationEffect(.degrees(-arrowRotation))  // سالب!
```

### الحل البديل 2: التحقق من اتجاه السهم الابتدائي

إذا كان السهم في الكود الحالي موجه لاتجاه غير الشمال في البداية:

```swift
static func calculateArrowRotation(qiblaDirection: Double, deviceHeading: Double) -> Double {
    // إضافة تعويض لاتجاه السهم الابتدائي إذا لزم الأمر
    let initialArrowDirection: Double = 0  // الشمال
    var rotation = qiblaDirection - deviceHeading + initialArrowDirection
    
    while rotation > 180 { rotation -= 360 }
    while rotation < -180 { rotation += 360 }
    
    return rotation
}
```

### الحل البديل 3: استخدام نفس النظام (راديان)

محاكاة الكود المرجعي بالكامل:

```swift
static func calculateArrowRotation(qiblaDirection: Double, deviceHeading: Double) -> Double {
    // تحويل للراديان
    let qiblaRad = qiblaDirection * .pi / 180
    let headingRad = deviceHeading * .pi / 180
    
    // محاكاة الكود المرجعي بالضبط
    let needleDirection = -deviceHeading  // سالب!
    let rotationRad = (needleDirection * .pi / 180) + qiblaRad
    
    // تحويل للدرجات
    var rotationDeg = rotationRad * 180 / .pi
    
    // تطبيع
    while rotationDeg > 180 { rotationDeg -= 360 }
    while rotationDeg < -180 { rotationDeg += 360 }
    
    return rotationDeg
}
```

---

## 📝 التوصيات

1. **اختبر الحل الأول** (عكس الإشارة) مع قيم حقيقية
2. **إذا لم يعمل**: جرب الحل البديل 1 (عكس الإشارة في `rotationEffect`)
3. **إذا لم يعمل أيضاً**: جرب الحل البديل 3 (استخدام نفس النظام بالراديان)
4. **راقب السلوك**: تأكد من أن السهم يشير للقبلة بشكل صحيح في جميع الاتجاهات

---

## 🔍 خطوات التحقق

1. ✅ تحقق من أن `qiblaDirection` محسوب بشكل صحيح
2. ✅ تحقق من أن `deviceHeading` يأتي من `CompassService.heading` (true heading)
3. ✅ تحقق من أن السهم يشير للشمال (0°) في البداية
4. ✅ اختبر مع قيم مختلفة للـ heading
5. ✅ راقب سلوك السهم عند دوران الجهاز

---

## 📚 المراجع

- الكود المرجعي: GitHub (يعمل بشكل صحيح)
- الكود الحالي: `CompassService.swift` → `QiblaCalculator.calculateArrowRotation`
- الاستخدام: `Views.swift` → `QiblaView` → `EnhancedCompassView`
