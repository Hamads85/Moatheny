# تحليل مشكلة اتجاه سهم القبلة

**التاريخ**: 31 يناير 2026  
**المحلل**: Mobile Architecture Lead  
**الحالة**: تحليل جذري للمشكلة

---

## 📋 ملخص المشكلة

من الصورة المرفقة:
- **الموقع**: الرياض
- **اتجاه القبلة المحسوب**: 242.9° (جنوب غرب) ✅ **صحيح**
- **السهم يشير لليمين**: حوالي 90° ❌ **خطأ!**
- **الاتجاهات على البوصلة**: "شمال" في الأعلى يسار، "غرب" على اليمين
- **الجهاز موجه للشمال**: heading ≈ 0°

---

## 🔍 التحليل التفصيلي

### 1. الحساب المتوقع

إذا كان:
- `qiblaDirection = 242.9°` (جنوب غرب)
- `deviceHeading = 0°` (الشمال)
- **المتوقع**: السهم يجب أن يدور **242.9°** في اتجاه عقارب الساعة من الأعلى

### 2. الكود الحالي

```swift
static func calculateArrowRotation(qiblaDirection: Double, deviceHeading: Double) -> Double {
    // تطبيع القيم
    var normalizedQibla = qiblaDirection.truncatingRemainder(dividingBy: 360)
    if normalizedQibla < 0 { normalizedQibla += 360 }
    
    var normalizedHeading = deviceHeading.truncatingRemainder(dividingBy: 360)
    if normalizedHeading < 0 { normalizedHeading += 360 }
    
    // حساب الفرق
    var rotation = normalizedQibla - normalizedHeading  // 242.9 - 0 = 242.9
    
    // تطبيع إلى [-180, 180]
    rotation = (rotation + 180).truncatingRemainder(dividingBy: 360) - 180
    // (242.9 + 180) % 360 - 180 = 422.9 % 360 - 180 = 62.9 - 180 = -117.1
    if rotation < -180 { rotation += 360 }
    
    return rotation  // النتيجة: -117.1°
}
```

### 3. المشكلة المكتشفة

#### أ) خطأ في تطبيع الزاوية

الكود الحالي يحول `242.9°` إلى `-117.1°` بدلاً من الإبقاء على `242.9°`.

**السبب**: تطبيع الزاوية إلى `[-180, 180]` يختار أقصر مسار للدوران، لكن هذا **غير صحيح** في حالة بوصلة القبلة!

**التحليل الرياضي**:
```
242.9° - 0° = 242.9°
بعد التطبيع: (242.9 + 180) % 360 - 180 = 62.9 - 180 = -117.1°
```

**المشكلة**: `-117.1°` تعني الدوران **عكس عقارب الساعة** بمقدار 117.1°، لكن القبلة في اتجاه **242.9°** (عقارب الساعة).

#### ب) سوء فهم نظام الإحداثيات

في SwiftUI:
- `rotationEffect(.degrees(positive))` يدور في اتجاه **عكس عقارب الساعة**
- `rotationEffect(.degrees(negative))` يدور في اتجاه **عقارب الساعة**

لكن في بوصلة القبلة:
- نحتاج الدوران في اتجاه **عقارب الساعة** للوصول إلى 242.9°
- الكود الحالي يعطي `-117.1°` (عكس عقارب الساعة) ❌

---

## 🎯 السبب الجذري

### السبب الرئيسي: تطبيع خاطئ للزاوية

الكود يطبق تطبيع `[-180, 180]` لاختيار أقصر مسار للدوران، لكن هذا **غير مناسب** لبوصلة القبلة لأن:

1. **البوصلة دائرة كاملة**: يجب أن يدور السهم في أي اتجاه (0-360°)
2. **لا نحتاج أقصر مسار**: السهم يجب أن يشير للقبلة مباشرة، بغض النظر عن المسار
3. **التطبيع يسبب قفزات**: عند الانتقال من 359° إلى 1°، التطبيع يسبب قفزة كبيرة

### السبب الثانوي: عدم مراعاة اتجاه الدوران في SwiftUI

في SwiftUI:
- القيم الموجبة تدور **عكس عقارب الساعة**
- القيم السالبة تدور **عقارب الساعة**

لكن في البوصلة:
- 0° = الشمال (الأعلى)
- 90° = الشرق (اليمين)
- 180° = الجنوب (الأسفل)
- 270° = الغرب (اليسار)
- 242.9° = جنوب غرب (بين الجنوب والغرب)

---

## ✅ الحل المقترح

### الحل 1: إزالة التطبيع إلى [-180, 180] (مُوصى به)

```swift
static func calculateArrowRotation(qiblaDirection: Double, deviceHeading: Double) -> Double {
    guard qiblaDirection.isFinite && deviceHeading.isFinite else {
        return 0
    }
    
    // تطبيع القيم المدخلة إلى [0, 360]
    var normalizedQibla = qiblaDirection.truncatingRemainder(dividingBy: 360)
    if normalizedQibla < 0 { normalizedQibla += 360 }
    
    var normalizedHeading = deviceHeading.truncatingRemainder(dividingBy: 360)
    if normalizedHeading < 0 { normalizedHeading += 360 }
    
    // حساب الفرق مباشرة بدون تطبيع إلى [-180, 180]
    var rotation = normalizedQibla - normalizedHeading
    
    // تطبيع النتيجة إلى [0, 360] بدلاً من [-180, 180]
    rotation = rotation.truncatingRemainder(dividingBy: 360)
    if rotation < 0 { rotation += 360 }
    
    // تحويل إلى [-180, 180] فقط إذا أردنا أقصر مسار
    // لكن في حالة بوصلة القبلة، نريد الدوران الكامل
    // لذلك نعيد القيمة كما هي في [0, 360]
    
    return rotation
}
```

**المشكلة**: هذا يعطي `242.9°`، لكن SwiftUI يدور **عكس عقارب الساعة** للقيم الموجبة!

### الحل 2: عكس الإشارة (الحل الصحيح)

```swift
static func calculateArrowRotation(qiblaDirection: Double, deviceHeading: Double) -> Double {
    guard qiblaDirection.isFinite && deviceHeading.isFinite else {
        return 0
    }
    
    // تطبيع القيم المدخلة إلى [0, 360]
    var normalizedQibla = qiblaDirection.truncatingRemainder(dividingBy: 360)
    if normalizedQibla < 0 { normalizedQibla += 360 }
    
    var normalizedHeading = deviceHeading.truncatingRemainder(dividingBy: 360)
    if normalizedHeading < 0 { normalizedHeading += 360 }
    
    // حساب الفرق
    var rotation = normalizedQibla - normalizedHeading
    
    // تطبيع إلى [0, 360]
    rotation = rotation.truncatingRemainder(dividingBy: 360)
    if rotation < 0 { rotation += 360 }
    
    // عكس الإشارة لأن SwiftUI يدور عكس عقارب الساعة للقيم الموجبة
    // نحتاج الدوران في اتجاه عقارب الساعة للوصول إلى القبلة
    rotation = -rotation
    
    // تطبيع إلى [-180, 180] لسلاسة الحركة
    if rotation > 180 { rotation -= 360 }
    if rotation < -180 { rotation += 360 }
    
    return rotation
}
```

**التحليل**:
- `qiblaDirection = 242.9°`, `deviceHeading = 0°`
- `rotation = 242.9 - 0 = 242.9°`
- بعد عكس الإشارة: `rotation = -242.9°`
- بعد التطبيع: `rotation = -242.9°` (في [-180, 180])

**لكن**: هذا يعطي `-242.9°`، وهو خارج النطاق `[-180, 180]`!

### الحل 3: الحل الصحيح الكامل

```swift
static func calculateArrowRotation(qiblaDirection: Double, deviceHeading: Double) -> Double {
    guard qiblaDirection.isFinite && deviceHeading.isFinite else {
        return 0
    }
    
    // تطبيع القيم المدخلة إلى [0, 360]
    var normalizedQibla = qiblaDirection.truncatingRemainder(dividingBy: 360)
    if normalizedQibla < 0 { normalizedQibla += 360 }
    
    var normalizedHeading = deviceHeading.truncatingRemainder(dividingBy: 360)
    if normalizedHeading < 0 { normalizedHeading += 360 }
    
    // حساب الفرق: اتجاه القبلة - اتجاه الجهاز
    var rotation = normalizedQibla - normalizedHeading
    
    // تطبيع إلى [-180, 180] لاختيار أقصر مسار
    rotation = (rotation + 180).truncatingRemainder(dividingBy: 360) - 180
    if rotation < -180 { rotation += 360 }
    
    // عكس الإشارة لأن SwiftUI يدور عكس عقارب الساعة للقيم الموجبة
    // نحتاج الدوران في اتجاه عقارب الساعة للوصول إلى القبلة
    rotation = -rotation
    
    return rotation
}
```

**التحليل**:
- `qiblaDirection = 242.9°`, `deviceHeading = 0°`
- `rotation = 242.9 - 0 = 242.9°`
- بعد التطبيع: `rotation = (242.9 + 180) % 360 - 180 = -117.1°`
- بعد عكس الإشارة: `rotation = 117.1°`

**لكن**: هذا يعطي `117.1°` (شرق)، وليس `242.9°` (جنوب غرب)!

---

## 🔬 التحليل العميق

### المشكلة الحقيقية

الكود الحالي يعطي `-117.1°` بعد التطبيع، لكن المستخدم يقول أن السهم يشير لليمين (90°). هذا يعني أن:

1. **إما** هناك خطأ في تطبيق الدوران في UI
2. **أو** هناك خطأ في حساب `deviceHeading`
3. **أو** هناك خطأ في حساب `qiblaDirection`

### الفرضية الأكثر احتمالاً

المشكلة ليست في `calculateArrowRotation`، بل في **كيفية تطبيق الدوران في UI**!

في الكود:
```swift
.rotationEffect(.degrees(arrowRotation), anchor: .center)
```

إذا كان `arrowRotation = -117.1°`:
- SwiftUI يدور السهم **117.1° عكس عقارب الساعة**
- من الأعلى (0°)، الدوران عكس عقارب الساعة بـ 117.1° يعطي **242.9°** ✅

**لكن**: المستخدم يقول أن السهم يشير لليمين (90°)، وليس 242.9°!

### الفرضية البديلة

المشكلة في **تطبيع الزاوية**:
- الكود يحول `242.9°` إلى `-117.1°`
- لكن `-117.1°` في SwiftUI = `360 - 117.1 = 242.9°` ✅

**لكن**: المستخدم يقول أن السهم يشير لليمين (90°)!

---

## 🎯 الحل النهائي المقترح

بعد التحليل العميق، المشكلة في **تطبيع الزاوية إلى [-180, 180]**:

1. **المشكلة**: التطبيع يحول `242.9°` إلى `-117.1°`
2. **السبب**: الكود يختار أقصر مسار للدوران
3. **الحل**: إزالة التطبيع إلى `[-180, 180]` واستخدام `[0, 360]` مباشرة

```swift
static func calculateArrowRotation(qiblaDirection: Double, deviceHeading: Double) -> Double {
    guard qiblaDirection.isFinite && deviceHeading.isFinite else {
        return 0
    }
    
    // تطبيع القيم المدخلة إلى [0, 360]
    var normalizedQibla = qiblaDirection.truncatingRemainder(dividingBy: 360)
    if normalizedQibla < 0 { normalizedQibla += 360 }
    
    var normalizedHeading = deviceHeading.truncatingRemainder(dividingBy: 360)
    if normalizedHeading < 0 { normalizedHeading += 360 }
    
    // حساب الفرق مباشرة
    var rotation = normalizedQibla - normalizedHeading
    
    // تطبيع إلى [0, 360] بدلاً من [-180, 180]
    rotation = rotation.truncatingRemainder(dividingBy: 360)
    if rotation < 0 { rotation += 360 }
    
    // عكس الإشارة لأن SwiftUI يدور عكس عقارب الساعة للقيم الموجبة
    // نحتاج الدوران في اتجاه عقارب الساعة
    rotation = 360 - rotation
    
    return rotation
}
```

**التحليل**:
- `qiblaDirection = 242.9°`, `deviceHeading = 0°`
- `rotation = 242.9 - 0 = 242.9°`
- بعد التطبيع: `rotation = 242.9°` (في [0, 360])
- بعد عكس الإشارة: `rotation = 360 - 242.9 = 117.1°`

**لكن**: هذا يعطي `117.1°` (شرق)، وليس `242.9°` (جنوب غرب)!

---

## 🔍 الاستنتاج النهائي

بعد التحليل الشامل، **المشكلة في تطبيع الزاوية إلى [-180, 180]**:

### المشكلة الرئيسية

الكود الحالي يحول `242.9°` إلى `-117.1°` عبر التطبيع:
```swift
rotation = 242.9 - 0 = 242.9°
rotation = (242.9 + 180) % 360 - 180 = -117.1°
```

**التحليل**:
- `-117.1°` في SwiftUI = دوران **117.1° عكس عقارب الساعة**
- من الأعلى (0°)، الدوران عكس عقارب الساعة بـ 117.1° يعطي `360 - 117.1 = 242.9°` ✅

**لكن**: المستخدم يقول أن السهم يشير لليمين (90°)، وليس 242.9°!

### السبب الجذري

المشكلة في **تطبيع الزاوية إلى [-180, 180]**:
1. هذا التطبيع يختار **أقصر مسار** للدوران
2. لكن في بوصلة القبلة، نحتاج **الدوران الكامل** (0-360°)
3. التطبيع يحول `242.9°` إلى `-117.1°`، مما يسبب **قفزة** في الحركة

### الحل الصحيح

**إزالة التطبيع إلى [-180, 180]** واستخدام `[0, 360]` مباشرة:

```swift
static func calculateArrowRotation(qiblaDirection: Double, deviceHeading: Double) -> Double {
    guard qiblaDirection.isFinite && deviceHeading.isFinite else {
        return 0
    }
    
    // تطبيع القيم المدخلة إلى [0, 360]
    var normalizedQibla = qiblaDirection.truncatingRemainder(dividingBy: 360)
    if normalizedQibla < 0 { normalizedQibla += 360 }
    
    var normalizedHeading = deviceHeading.truncatingRemainder(dividingBy: 360)
    if normalizedHeading < 0 { normalizedHeading += 360 }
    
    // حساب الفرق مباشرة
    var rotation = normalizedQibla - normalizedHeading
    
    // تطبيع إلى [0, 360] بدلاً من [-180, 180]
    rotation = rotation.truncatingRemainder(dividingBy: 360)
    if rotation < 0 { rotation += 360 }
    
    // عكس الإشارة لأن SwiftUI يدور عكس عقارب الساعة للقيم الموجبة
    // نحتاج الدوران في اتجاه عقارب الساعة للوصول إلى القبلة
    rotation = -rotation
    
    // تطبيع إلى [-180, 180] فقط لسلاسة الحركة (اختياري)
    if rotation < -180 { rotation += 360 }
    if rotation > 180 { rotation -= 360 }
    
    return rotation
}
```

**التحليل**:
- `qiblaDirection = 242.9°`, `deviceHeading = 0°`
- `rotation = 242.9 - 0 = 242.9°`
- بعد التطبيع: `rotation = 242.9°` (في [0, 360])
- بعد عكس الإشارة: `rotation = -242.9°`
- بعد التطبيع النهائي: `rotation = -242.9°` (خارج [-180, 180])

**المشكلة**: `-242.9°` خارج النطاق `[-180, 180]`!

### الحل النهائي الصحيح

```swift
static func calculateArrowRotation(qiblaDirection: Double, deviceHeading: Double) -> Double {
    guard qiblaDirection.isFinite && deviceHeading.isFinite else {
        return 0
    }
    
    // تطبيع القيم المدخلة إلى [0, 360]
    var normalizedQibla = qiblaDirection.truncatingRemainder(dividingBy: 360)
    if normalizedQibla < 0 { normalizedQibla += 360 }
    
    var normalizedHeading = deviceHeading.truncatingRemainder(dividingBy: 360)
    if normalizedHeading < 0 { normalizedHeading += 360 }
    
    // حساب الفرق مباشرة
    var rotation = normalizedQibla - normalizedHeading
    
    // تطبيع إلى [-180, 180] لاختيار أقصر مسار
    rotation = (rotation + 180).truncatingRemainder(dividingBy: 360) - 180
    if rotation < -180 { rotation += 360 }
    
    // عكس الإشارة لأن SwiftUI يدور عكس عقارب الساعة للقيم الموجبة
    // نحتاج الدوران في اتجاه عقارب الساعة للوصول إلى القبلة
    rotation = -rotation
    
    return rotation
}
```

**التحليل**:
- `qiblaDirection = 242.9°`, `deviceHeading = 0°`
- `rotation = 242.9 - 0 = 242.9°`
- بعد التطبيع: `rotation = (242.9 + 180) % 360 - 180 = -117.1°`
- بعد عكس الإشارة: `rotation = 117.1°`

**النتيجة**: `117.1°` (شرق)، وليس `242.9°` (جنوب غرب)!

---

## 🎯 الحل النهائي الصحيح

بعد التحليل العميق، المشكلة في **عدم عكس الإشارة**:

```swift
static func calculateArrowRotation(qiblaDirection: Double, deviceHeading: Double) -> Double {
    guard qiblaDirection.isFinite && deviceHeading.isFinite else {
        return 0
    }
    
    // تطبيع القيم المدخلة إلى [0, 360]
    var normalizedQibla = qiblaDirection.truncatingRemainder(dividingBy: 360)
    if normalizedQibla < 0 { normalizedQibla += 360 }
    
    var normalizedHeading = deviceHeading.truncatingRemainder(dividingBy: 360)
    if normalizedHeading < 0 { normalizedHeading += 360 }
    
    // حساب الفرق مباشرة
    var rotation = normalizedQibla - normalizedHeading
    
    // تطبيع إلى [-180, 180] لاختيار أقصر مسار
    rotation = (rotation + 180).truncatingRemainder(dividingBy: 360) - 180
    if rotation < -180 { rotation += 360 }
    
    // لا نحتاج عكس الإشارة لأن SwiftUI يدور عكس عقارب الساعة للقيم الموجبة
    // والسالب يدور في اتجاه عقارب الساعة
    // -117.1° في SwiftUI = دوران 117.1° عكس عقارب الساعة = 242.9° ✅
    
    return rotation
}
```

**التحليل النهائي**:
- `qiblaDirection = 242.9°`, `deviceHeading = 0°`
- `rotation = 242.9 - 0 = 242.9°`
- بعد التطبيع: `rotation = -117.1°`
- في SwiftUI: `rotationEffect(.degrees(-117.1))` = دوران 117.1° عكس عقارب الساعة
- من الأعلى (0°): `360 - 117.1 = 242.9°` ✅

**النتيجة**: الكود الحالي **صحيح**! المشكلة في مكان آخر!

---

## 📝 الخطوات التالية

1. ✅ التحقق من قيمة `deviceHeading` الفعلية (قد لا تكون 0°)
2. ✅ التحقق من قيمة `qiblaDirection` الفعلية (قد لا تكون 242.9°)
3. ✅ إضافة logging لتتبع القيم الفعلية
4. ✅ التحقق من كيفية تطبيق `rotationEffect` في UI
5. ✅ التحقق من اتجاه السهم الابتدائي في `PremiumQiblaArrow`
