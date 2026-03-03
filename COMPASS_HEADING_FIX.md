# إصلاح مشكلة قراءة Heading في iOS

## المشكلة
التطبيق كان يظهر اتجاه 154° SE بينما بوصلة iOS تظهر 242° SW. الفرق حوالي 88°.

## الأسباب المحتملة

### 1. ❌ **عدم تعيين `headingOrientation`** (مشكلة حرجة)
- **المشكلة**: لم يتم تعيين `locationManager.headingOrientation` في `startUpdating()`
- **التأثير**: iOS يحتاج معرفة اتجاه الجهاز (portrait, landscape, etc.) لحساب heading بشكل صحيح
- **النتيجة**: قراءات خاطئة للـ heading

### 2. ❌ **صيغة خاطئة في `extractHeadingFromMotion`**
- **المشكلة**: الصيغة `headingDeg = 360.0 - yawDeg` كانت خاطئة
- **التأثير**: في iOS، yaw يعطي الزاوية من -π إلى π، حيث 0 = الشمال
- **الصيغة الصحيحة**: `headingDeg = -yawRad * 180.0 / π` ثم تطبيع

### 3. ⚠️ **عدم تحديث `headingOrientation` عند تغيير الوضعية**
- **المشكلة**: عند تغيير وضعية الجهاز (portrait → landscape)، لم يتم تحديث `headingOrientation`
- **التأثير**: قراءات خاطئة عند تغيير الوضعية

## الحلول المطبقة

### 1. ✅ إضافة تعيين `headingOrientation` في `startUpdating()`
```swift
// ⚠️ مهم جداً: تعيين headingOrientation لضمان قراءة صحيحة للـ heading
locationManager.headingOrientation = .portrait
```

### 2. ✅ تصحيح صيغة `extractHeadingFromMotion`
```swift
// الصيغة الصحيحة
let yawRad = motion.attitude.yaw
var headingDeg = -yawRad * 180.0 / .pi
while headingDeg < 0 { headingDeg += 360 }
while headingDeg >= 360 { headingDeg -= 360 }
```

### 3. ✅ تحديث `headingOrientation` تلقائياً عند تغيير الوضعية
```swift
// في updateDeviceOrientation()
if locationManager.headingOrientation != headingOrientation {
    locationManager.headingOrientation = headingOrientation
}
```

### 4. ✅ تحسين Logging لتتبع المشكلة
- إضافة logging لاستخدام `trueHeading` vs `magneticHeading`
- إضافة `headingOrientation` في DebugFileLogger
- تسجيل القيم الفعلية للـ heading

## التحقق من الاستخدام الصحيح

### استخدام `trueHeading` vs `magneticHeading`
✅ **الكود صحيح**: يتم التحقق من `trueHeading` أولاً، وإذا لم يكن متاحاً، يتم استخدام `magneticHeading` مع تطبيق تعويض الانحراف المغناطيسي.

```swift
if newHeading.trueHeading >= 0 && newHeading.trueHeading <= 360 {
    // استخدام trueHeading مباشرة (لا يحتاج تعويض)
    headingValue = newHeading.trueHeading
    isTrueHeading = true
} else if newHeading.magneticHeading >= 0 && newHeading.magneticHeading <= 360 {
    // استخدام magneticHeading مع تطبيق تعويض الانحراف لاحقاً
    headingValue = newHeading.magneticHeading
    isTrueHeading = false
}
```

## التوصيات للاختبار

1. **اختبار مع وضعيات مختلفة**:
   - Portrait
   - Landscape Left/Right
   - Portrait Upside Down

2. **التحقق من `trueHeading`**:
   - تأكد من أن GPS يعمل
   - تأكد من أن الموقع دقيق
   - تحقق من أن `trueHeading` متاح (>= 0)

3. **مقارنة مع بوصلة iOS**:
   - قارن القراءات مع بوصلة iOS الأصلية
   - تأكد من أن الفرق أقل من 5°

4. **مراقبة Logs**:
   - تحقق من استخدام `trueHeading` vs `magneticHeading`
   - تحقق من تحديث `headingOrientation`
   - راقب تطبيق تعويض الانحراف المغناطيسي

## ملاحظات إضافية

- `headingOrientation` يجب أن يتطابق مع `deviceOrientation` الحالي
- عند تغيير الوضعية، يجب تحديث `headingOrientation` فوراً
- `trueHeading` يتطلب GPS وموقع دقيق - قد يكون غير متاح في البداية
- إذا كان `trueHeading` غير متاح، يتم استخدام `magneticHeading` مع تطبيق تعويض الانحراف المغناطيسي

## المراجع

- [Apple Documentation: CLLocationManager.headingOrientation](https://developer.apple.com/documentation/corelocation/cllocationmanager/1620550-headingorientation)
- [Apple Documentation: CLHeading](https://developer.apple.com/documentation/corelocation/clheading)
- [Apple Documentation: CMDeviceMotion.attitude.yaw](https://developer.apple.com/documentation/coremotion/cmdevicemotion/1616129-attitude)
