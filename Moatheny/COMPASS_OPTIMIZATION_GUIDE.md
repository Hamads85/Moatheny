# دليل تحسين البوصلة - CoreLocation & CoreMotion

## نظرة عامة

تم تحسين `CompassService` لاستخدام أفضل ممارسات iOS للحصول على دقة قصوى في قراءة البوصلة مع تعويض الميلان ودعم جميع الوضعيات.

---

## التحسينات المطبقة

### 1. إعدادات CoreLocation المحسنة

#### headingFilter
```swift
locationManager.headingFilter = 1.0 // درجة واحدة
```

**التوصية:**
- **1.0 درجة**: توازن مثالي بين الدقة والأداء (مستحسن)
- **0.5 درجة**: تحديثات أكثر = دقة أعلى لكن استهلاك بطارية أعلى
- **5.0 درجة**: تحديثات أقل = استجابة أبطأ لكن توفير بطارية
- **kCLHeadingFilterNone**: تحديث فوري لكل تغيير (غير مستحسن - استهلاك بطارية عالي)

#### desiredAccuracy
```swift
locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
```

**المميزات:**
- أعلى دقة متاحة مع GPS + GLONASS + Galileo
- مطلوب للحصول على `trueHeading` (الشمال الحقيقي) بدلاً من `magneticHeading`
- يعطي دقة أفضل في المناطق الحضرية والمناطق المغلقة

**البدائل:**
- `kCLLocationAccuracyBest`: دقة عالية لكن أقل من BestForNavigation
- `kCLLocationAccuracyHundredMeters`: دقة متوسطة (غير مستحسن للبوصلة)

---

### 2. إعدادات CoreMotion المحسنة

#### deviceMotionUpdateInterval
```swift
motionManager.deviceMotionUpdateInterval = 1.0 / 60.0 // 60 Hz
```

**التوصيات حسب الاستخدام:**

| الاستخدام | التردد الموصى به | السبب |
|-----------|------------------|-------|
| بوصلة عادية | 30 Hz (`1.0/30.0`) | توازن جيد بين الدقة والأداء |
| بوصلة عالية الدقة | 60 Hz (`1.0/60.0`) | دقة قصوى في تعويض الميلان |
| توفير البطارية | 10 Hz (`1.0/10.0`) | استهلاك أقل لكن دقة أقل |

**ملاحظة:** 60 Hz يعطي نتائج أفضل عند الحركة أو الميلان الشديد.

#### CMAttitudeReferenceFrame

**الأولوية الموصى بها:**

1. **`.xTrueNorthZVertical`** (الأفضل)
   - يعطي الشمال الحقيقي مع تعويض الميلان
   - يتطلب موقع GPS دقيق
   - متاح على معظم الأجهزة الحديثة

2. **`.xMagneticNorthZVertical`** (بديل جيد)
   - يعطي الشمال المغناطيسي مع تعويض الميلان
   - لا يتطلب GPS
   - متاح على جميع الأجهزة

3. **`.xArbitraryCorrectedZVertical`** (بديل)
   - يعوض الميلان لكن لا يعطي اتجاه الشمال
   - يستخدم مع CLHeading للحصول على الاتجاه

---

### 3. استخدام gravity و userAcceleration

#### CMDeviceMotion.gravity
```swift
let gravity = motion.gravity
let gravityMagnitude = sqrt(gravity.x * gravity.x + gravity.y * gravity.y + gravity.z * gravity.z)
```

**الاستخدامات:**
- **تحديد الوضعية بدقة**: Face Up/Down, Portrait, Landscape
- **التحقق من الاستقرار**: إذا كانت `gravityMagnitude` قريبة من 1.0، الجهاز ثابت
- **تحسين الدقة**: عند الميلان الشديد، يمكن استخدام gravity لتحسين القراءة

#### CMDeviceMotion.userAcceleration
```swift
let userAccel = motion.userAcceleration
let accelMagnitude = sqrt(userAccel.x * userAccel.x + userAccel.y * userAccel.y + userAccel.z * userAccel.z)
```

**الاستخدامات:**
- **كشف الحركة**: إذا كان `accelMagnitude > threshold`، الجهاز يتحرك
- **تعديل الفلتر**: عند الحركة، يمكن تعديل معاملات Kalman filter للاستجابة الأسرع
- **تحسين الأداء**: عند التوقف، يمكن تقليل التحديثات لتوفير البطارية

---

### 4. إدارة الأذونات المحسنة

#### Always Authorization للدقة القصوى

```swift
// طلب Always authorization
locationManager.requestAlwaysAuthorization()

// تفعيل تحديثات الخلفية
locationManager.allowsBackgroundLocationUpdates = true
```

**المميزات:**
- دقة أعلى في قراءة البوصلة
- تحديثات مستمرة حتى في الخلفية
- أفضل أداء مع `kCLLocationAccuracyBestForNavigation`

**ملاحظات مهمة:**
- iOS سيطلب من المستخدم الموافقة في الإعدادات
- يجب إضافة `NSLocationAlwaysAndWhenInUseUsageDescription` في Info.plist
- المستخدم قد يرفض - يجب التعامل مع `.authorizedWhenInUse` كبديل

#### تدفق طلب الأذونات

```
1. notDetermined → requestWhenInUseAuthorization()
2. authorizedWhenInUse → requestAlwaysAuthorization()
3. authorizedAlways → ✅ دقة قصوى متاحة
```

---

### 5. دعم الوضعيات المختلفة

#### الوضعيات المدعومة

| الوضعية | gravity.x | gravity.y | gravity.z | الاستخدام |
|---------|-----------|------------|-----------|-----------|
| **Portrait** | ~0 | ~-1.0 | ~0 | الوضعية الافتراضية |
| **Portrait Upside Down** | ~0 | ~1.0 | ~0 | نادر الاستخدام |
| **Landscape Left** | ~-1.0 | ~0 | ~0 | مفيد للعرض الأفقي |
| **Landscape Right** | ~1.0 | ~0 | ~0 | مفيد للعرض الأفقي |
| **Face Up** | ~0 | ~0 | ~-1.0 | الجهاز مسطح للأعلى |
| **Face Down** | ~0 | ~0 | ~1.0 | الجهاز مسطح للأسفل |

#### تعويض الميلان

```swift
// تفعيل/تعطيل تعويض الميلان
compassService.setTiltCompensation(true)
```

**كيف يعمل:**
- `CMAttitudeReferenceFrame.xTrueNorthZVertical` يعوض الميلان تلقائياً
- عند الميلان الشديد (pitch/roll > 45°)، قد تقل الدقة
- يمكن استخدام `gravity` للتحقق من جودة القراءة

---

## أفضل الممارسات

### 1. تهيئة البوصلة

```swift
let compass = CompassService()

// طلب الأذونات
compass.requestLocationPermission()

// بدء التحديثات
compass.startUpdating()

// تفعيل تعويض الميلان
compass.setTiltCompensation(true)
```

### 2. التعامل مع الأخطاء

```swift
// مراقبة حالة الخطأ
compass.$error
    .sink { error in
        if let error = error {
            // عرض رسالة خطأ للمستخدم
            print("خطأ البوصلة: \(error)")
        }
    }
```

### 3. مراقبة حالة المعايرة

```swift
// التحقق من الحاجة للمعايرة
compass.$calibrationNeeded
    .sink { needsCalibration in
        if needsCalibration {
            // عرض رسالة للمستخدم لمعايرة البوصلة
            // iOS سيعرض شاشة المعايرة تلقائياً
        }
    }
```

### 4. تحسين الأداء

```swift
// عند دخول الخلفية
func applicationDidEnterBackground() {
    // تقليل التحديثات لتوفير البطارية
    // يمكن تقليل deviceMotionUpdateInterval إلى 10 Hz
}

// عند العودة للمقدمة
func applicationWillEnterForeground() {
    // استعادة التحديثات الكاملة
    // استعادة deviceMotionUpdateInterval إلى 60 Hz
}
```

---

## الإعدادات الموصى بها حسب الحالة

### حالة الاستخدام العادي
```swift
headingFilter = 1.0
desiredAccuracy = kCLLocationAccuracyBestForNavigation
deviceMotionUpdateInterval = 1.0 / 30.0 // 30 Hz
authorization = .authorizedWhenInUse
```

### حالة الاستخدام عالي الدقة
```swift
headingFilter = 0.5
desiredAccuracy = kCLLocationAccuracyBestForNavigation
deviceMotionUpdateInterval = 1.0 / 60.0 // 60 Hz
authorization = .authorizedAlways
tiltCompensation = true
```

### حالة توفير البطارية
```swift
headingFilter = 2.0
desiredAccuracy = kCLLocationAccuracyBest
deviceMotionUpdateInterval = 1.0 / 10.0 // 10 Hz
authorization = .authorizedWhenInUse
```

---

## استكشاف الأخطاء

### المشكلة: البوصلة غير دقيقة
**الحلول:**
1. التحقق من المعايرة (`calibrationNeeded`)
2. التأكد من وجود GPS signal (للحصول على true heading)
3. التحقق من عدم وجود تداخل مغناطيسي (أجهزة إلكترونية قريبة)
4. التأكد من استخدام `.xTrueNorthZVertical` إذا كان متاحاً

### المشكلة: استهلاك بطارية عالي
**الحلول:**
1. زيادة `headingFilter` إلى 2.0 أو أكثر
2. تقليل `deviceMotionUpdateInterval` إلى 10 Hz
3. استخدام `.authorizedWhenInUse` بدلاً من Always
4. إيقاف التحديثات عند عدم الحاجة

### المشكلة: القراءة غير مستقرة
**الحلول:**
1. التحقق من معاملات Kalman filter
2. زيادة `stabilityThreshold` في الفلتر
3. التأكد من عدم وجود حركة مستمرة (`isDeviceMoving`)
4. التحقق من جودة المجال المغناطيسي (`magneticField.accuracy`)

---

## مراجع

- [Apple CoreLocation Documentation](https://developer.apple.com/documentation/corelocation)
- [Apple CoreMotion Documentation](https://developer.apple.com/documentation/coremotion)
- [CLHeading Class Reference](https://developer.apple.com/documentation/corelocation/clheading)
- [CMDeviceMotion Class Reference](https://developer.apple.com/documentation/coremotion/cmdevicemotion)

---

## ملاحظات إضافية

### iOS Version Compatibility
- `kCLLocationAccuracyBestForNavigation`: متاح من iOS 4.0+
- `CMAttitudeReferenceFrame.xTrueNorthZVertical`: متاح من iOS 5.0+
- `allowsBackgroundLocationUpdates`: متاح من iOS 9.0+

### الأجهزة المدعومة
- جميع أجهزة iPhone و iPad التي تحتوي على بوصلة
- يتطلب GPS للشمال الحقيقي (true heading)
- يتطلب motion coprocessor لـ CoreMotion

---

**آخر تحديث:** 30 يناير 2026
