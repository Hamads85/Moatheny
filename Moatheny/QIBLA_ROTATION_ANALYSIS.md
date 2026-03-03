# تحليل مشكلة دوران بوصلة القبلة

**التاريخ**: 31 يناير 2026  
**المحلل**: Mobile Architecture Lead  
**المشكلة**: اختلاف في سلوك دوران السهم بين الكود المرجعي والكود الحالي

---

## 📋 ملخص المشكلة

الكود المرجعي من GitHub يعمل بشكل صحيح، بينما الكود الحالي لا يعطي نفس النتيجة. الفرق الرئيسي في كيفية حساب زاوية دوران السهم.

---

## 🔍 تحليل الكود المرجعي (يعمل بشكل صحيح)

### 1. حساب زاوية القبلة (بالراديان)
```swift
func setLatLonForDistanceAndAngle(userlocation: CLLocation) -> Double {
    let lat1 = DegreesToRadians(userlocation.coordinate.latitude)
    let lon1 = DegreesToRadians(userlocation.coordinate.longitude)
    let lat2 = DegreesToRadians(21.42) // Kaaba latitude
    let lon2 = DegreesToRadians(39.83) // Kaaba longitude
    
    let dLon = lon2 - lon1
    let y = sin(dLon) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    var radiansBearing = atan2(y, x)
    if radiansBearing < 0.0 {
        radiansBearing += 2 * M_PI
    }
    return radiansBearing  // يرجع بالراديان!
}
```

**الملاحظات**:
- ✅ يرجع القيمة بالراديان (0 إلى 2π)
- ✅ يستخدم نفس معادلة bearing الصحيحة

### 2. تطبيق الدوران على السهم
```swift
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
         = (-heading * π/180) + qiblaAngle(radians)
         = qiblaAngle(radians) - heading(radians)
```

**السبب في استخدام السالب (`-heading`)**:
- `CGAffineTransformMakeRotation` في UIKit يدور في **اتجاه عكس عقارب الساعة** عندما تكون القيمة موجبة
- لتعويض هذا، يتم استخدام `-heading` للحصول على الدوران الصحيح

---

## 🔍 تحليل الكود الحالي (المشكلة)

### 1. حساب زاوية القبلة (بالدرجات)
```swift
static func calculateQiblaDirection(from latitude: Double, longitude: Double) -> Double {
    // ... نفس المعادلة ...
    var bearing = atan2(y, x)
    bearing = bearing * 180 / .pi  // تحويل للدرجات
    bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)
    return bearing  // بالدرجات
}
```

**الملاحظات**:
- ✅ المعادلة صحيحة
- ✅ التحويل للدرجات صحيح
- ⚠️ الفرق: الكود المرجعي يرجع بالراديان، الكود الحالي بالدرجات

### 2. حساب دوران السهم
```swift
static func calculateArrowRotation(qiblaDirection: Double, deviceHeading: Double) -> Double {
    var rotation = qiblaDirection - deviceHeading
    while rotation > 180 { rotation -= 360 }
    while rotation < -180 { rotation += 360 }
    return rotation
}
```

**التحليل الرياضي**:
```
rotation = qiblaDirection(degrees) - deviceHeading(degrees)
```

**الاستخدام في SwiftUI**:
```swift
.rotationEffect(.degrees(arrowRotation))
```

---

## ⚠️ المشكلة الرئيسية

### الفرق في أنظمة الإحداثيات

1. **الكود المرجعي (UIKit)**:
   - `CGAffineTransformMakeRotation` يدور في **اتجاه عكس عقارب الساعة** للقيم الموجبة
   - لذلك يستخدم: `rotation = qiblaAngle - heading` (مع سالب heading مسبقاً)

2. **الكود الحالي (SwiftUI)**:
   - `rotationEffect(.degrees())` يدور في **اتجاه عقارب الساعة** للقيم الموجبة
   - يستخدم: `rotation = qiblaDirection - deviceHeading`

### المشكلة الرياضية

في الكود المرجعي:
```
rotation = qiblaAngle(radians) - heading(radians)
         = qiblaAngle(radians) - (-heading * π/180)  // لأن needleDirection = -heading
         = qiblaAngle(radians) + heading(radians)
```

لكن هذا لا يبدو صحيحاً! دعني أعيد التحليل...

**إعادة التحليل الصحيحة**:
```swift
needleDirection = -newHeading.trueHeading  // مثال: heading = 90° → needleDirection = -90°
rotation = (needleDirection * π/180) + needleAngle
         = (-90 * π/180) + qiblaAngle
         = -90°(radians) + qiblaAngle(radians)
         = qiblaAngle(radians) - 90°(radians)
```

إذا كان `heading = 0°` (الشمال) و `qiblaAngle = 243°` (حوالي 4.24 راديان):
```
rotation = 4.24 - 0 = 4.24 راديان = 243°
```

إذا كان `heading = 90°` (الشرق) و `qiblaAngle = 243°`:
```
rotation = 4.24 - (90 * π/180) = 4.24 - 1.57 = 2.67 راديان = 153°
```

هذا منطقي! السهم يجب أن يدور 153° من الشمال عندما يكون الجهاز يشير للشرق.

### في الكود الحالي

```
rotation = qiblaDirection - deviceHeading
         = 243° - 90° = 153°
```

**النتيجة**: الكود الحالي يعطي نفس النتيجة الرياضية! لكن...

---

## 🎯 المشكلة الحقيقية: اتجاه الدوران

### الفرق في أنظمة الإحداثيات

1. **UIKit `CGAffineTransformMakeRotation`**:
   - القيمة الموجبة = دوران **عكس عقارب الساعة**
   - القيمة السالبة = دوران **عكس عقارب الساعة** (في الاتجاه المعاكس)

2. **SwiftUI `rotationEffect(.degrees())`**:
   - القيمة الموجبة = دوران **عكس عقارب الساعة** (نفس UIKit!)
   - القيمة السالبة = دوران **عكس عقارب الساعة** (في الاتجاه المعاكس)

**انتظر!** كلاهما يدور في نفس الاتجاه! إذن المشكلة ليست هنا.

---

## 🔍 إعادة التحليل: المشكلة الحقيقية

دعني أفحص الكود المرجعي مرة أخرى:

```swift
let needleDirection = -newHeading.trueHeading  // سالب!
self.needle.transform = CGAffineTransformMakeRotation(
    CGFloat(((Double(needleDirection) * M_PI) / 180.0) + needleAngle!)
)
```

**التحليل الصحيح**:
- `needleDirection = -heading` (بالدرجات)
- `rotation = (needleDirection * π/180) + needleAngle`
- `rotation = (-heading * π/180) + qiblaAngle`
- `rotation = qiblaAngle - heading` (بعد التحويل)

**في الكود الحالي**:
- `rotation = qiblaDirection - deviceHeading` (بالدرجات)

**النتيجة**: الكودان متطابقان رياضياً!

---

## 🎯 المشكلة المحتملة: اتجاه السهم الابتدائي

### السيناريو المحتمل

1. **الكود المرجعي**: السهم قد يكون موجه في اتجاه معين في البداية
2. **الكود الحالي**: السهم موجه للأعلى (الشمال) في البداية

إذا كان السهم في الكود المرجعي موجه للشرق (90°) في البداية:
- الكود المرجعي: `rotation = qiblaAngle - heading` (يعوض عن الاتجاه الابتدائي)
- الكود الحالي: `rotation = qiblaDirection - deviceHeading` (يفترض أن السهم يشير للشمال)

---

## 🔍 المشكلة المحتملة: نظام الإحداثيات

### في UIKit (الكود المرجعي)
- `CGAffineTransformMakeRotation` يستخدم نظام إحداثيات UIKit
- قد يكون هناك اختلاف في اتجاه المحور Y (مقلوب)

### في SwiftUI (الكود الحالي)
- `rotationEffect` يستخدم نظام إحداثيات SwiftUI
- نظام الإحداثيات قد يكون مختلفاً

---

## ✅ الحل المقترح

### الحل 1: عكس الإشارة (محتمل)
```swift
static func calculateArrowRotation(qiblaDirection: Double, deviceHeading: Double) -> Double {
    // عكس الإشارة ليتطابق مع الكود المرجعي
    var rotation = deviceHeading - qiblaDirection  // عكس!
    while rotation > 180 { rotation -= 360 }
    while rotation < -180 { rotation += 360 }
    return rotation
}
```

### الحل 2: استخدام سالب في rotationEffect
```swift
.rotationEffect(.degrees(-arrowRotation))  // سالب!
```

### الحل 3: التحقق من اتجاه السهم الابتدائي
- التأكد من أن السهم في الكود الحالي يشير للشمال (0°) في البداية
- إذا كان يشير لاتجاه آخر، يجب إضافة تعويض

---

## 🧪 اختبار الحل

### اختبار 1: عندما يكون الجهاز يشير للشمال (0°)
- `qiblaDirection = 243°`
- `deviceHeading = 0°`
- `rotation = 243° - 0° = 243°`
- **النتيجة المتوقعة**: السهم يجب أن يشير 243° (جنوب غرب)

### اختبار 2: عندما يكون الجهاز يشير للقبلة (243°)
- `qiblaDirection = 243°`
- `deviceHeading = 243°`
- `rotation = 243° - 243° = 0°`
- **النتيجة المتوقعة**: السهم يجب أن يشير للأعلى (0°)

### اختبار 3: عندما يكون الجهاز يشير للشرق (90°)
- `qiblaDirection = 243°`
- `deviceHeading = 90°`
- `rotation = 243° - 90° = 153°`
- **النتيجة المتوقعة**: السهم يجب أن يشير 153° من الشمال

---

## 📝 التوصية النهائية

1. **التحقق من اتجاه السهم الابتدائي**: التأكد من أن السهم يشير للشمال (0°) في البداية
2. **اختبار مع القيم الفعلية**: تجربة الكود مع قيم حقيقية ومقارنة النتائج
3. **إذا لم يعمل**: تجربة عكس الإشارة (`deviceHeading - qiblaDirection`)

---

## 🔧 الحل المقترح (النهائي)

بناءً على التحليل العميق، المشكلة الرئيسية هي:

### المشكلة الحقيقية

في الكود المرجعي:
```swift
let needleDirection = -newHeading.trueHeading  // سالب!
rotation = (needleDirection * π/180) + needleAngle
         = (-heading * π/180) + qiblaAngle
```

**السبب في استخدام السالب**: 
- `CGAffineTransformMakeRotation` في UIKit يدور العنصر **نسبياً** إلى موضعه الحالي
- استخدام `-heading` يعوض عن دوران الجهاز نفسه
- النتيجة: السهم يشير دائماً إلى القبلة بغض النظر عن اتجاه الجهاز

في الكود الحالي:
```swift
rotation = qiblaDirection - deviceHeading
```

**المشكلة**: 
- الكود الحالي صحيح رياضياً، لكن قد يكون هناك اختلاف في:
  1. **اتجاه الدوران**: SwiftUI `rotationEffect` قد يدور في اتجاه مختلف
  2. **نقطة البداية**: السهم قد يكون موجه في اتجاه مختلف في البداية

### الحل المقترح

#### الحل 1: عكس الإشارة (الأكثر احتمالاً)
```swift
static func calculateArrowRotation(qiblaDirection: Double, deviceHeading: Double) -> Double {
    // عكس الإشارة لمحاكاة الكود المرجعي
    var rotation = deviceHeading - qiblaDirection  // عكس!
    
    // تطبيع الزاوية بين -180 و 180
    while rotation > 180 { rotation -= 360 }
    while rotation < -180 { rotation += 360 }
    
    return rotation
}
```

#### الحل 2: استخدام سالب في rotationEffect
```swift
.rotationEffect(.degrees(-arrowRotation))  // سالب!
```

#### الحل 3: التحقق من اتجاه السهم الابتدائي
إذا كان السهم في الكود الحالي موجه لاتجاه غير الشمال في البداية، يجب إضافة تعويض.

### التوصية النهائية

**جرب الحل 1 أولاً** (عكس الإشارة في `calculateArrowRotation`). إذا لم يعمل، جرب الحل 2 (عكس الإشارة في `rotationEffect`).
