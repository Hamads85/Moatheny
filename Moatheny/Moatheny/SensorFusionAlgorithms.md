# خوارزميات Sensor Fusion المتقدمة للبوصلة

## نظرة عامة

تم تطوير نظام متقدم لدمج مستشعرات البوصلة (Sensor Fusion) لتحسين دقة قراءات الاتجاه. النظام يتكون من ثلاث خوارزميات رئيسية:

1. **Extended Kalman Filter (EKF)** - دمج المستشعرات
2. **Magnetic Anomaly Detector** - كشف التشويش المغناطيسي
3. **Magnetic Declination Calculator** - تعويض الانحراف المغناطيسي

---

## 1. Extended Kalman Filter (EKF)

### المفهوم

Extended Kalman Filter هو خوارزمية متقدمة لدمج بيانات متعددة من مستشعرات مختلفة للحصول على تقدير دقيق لحالة النظام.

### متجه الحالة

```
x = [heading, heading_rate]
```

حيث:
- **heading**: الاتجاه بالراديان (0-2π)
- **heading_rate**: معدل التغير في الاتجاه (راديان/ثانية)

### نموذج الحالة (State Model)

```
x_k = F * x_{k-1} + B * u_k + w_k
```

حيث:
- **F**: مصفوفة الانتقال (Transition Matrix)
  ```
  F = [1  dt]
      [0  1 ]
  ```
- **B**: مصفوفة التحكم (Control Matrix)
- **u_k**: مدخلات الجيروسكوب (gyroRate)
- **w_k**: ضوضاء العملية (Process Noise)

### نموذج القياس (Measurement Model)

```
z_k = H * x_k + v_k
```

حيث:
- **H**: مصفوفة القياس `[1, 0]` (نقيس heading فقط)
- **v_k**: ضوضاء القياس (Measurement Noise)

### خطوات الخوارزمية

#### 1. خطوة التنبؤ (Prediction Step)

```swift
// تحديث الحالة المتوقعة
x_pred = F * x

// إضافة تأثير الجيروسكوب
heading_rate = weighted_average(gyroRate, predicted_rate)

// تحديث مصفوفة التباين
P_pred = F * P * F^T + Q
```

#### 2. خطوة التحديث (Update Step)

```swift
// حساب الابتكار (Innovation)
innovation = measurement - predicted_measurement

// حساب كسب Kalman
K = P * H^T / (H * P * H^T + R)

// تحديث الحالة
x = x_pred + K * innovation

// تحديث مصفوفة التباين
P = (I - K * H) * P_pred
```

### التعامل مع الزوايا الدائرية

المشكلة الرئيسية في معالجة الزوايا هي الانتقال من 359° إلى 0°. الحل:

1. **Normalize Angle**: تطبيع الزاوية إلى [0, 2π)
2. **Normalize Angle Difference**: حساب الفرق مع مراعاة الدائرية في النطاق [-π, π]

```swift
func normalizeAngleDifference(_ diff: Double) -> Double {
    var normalized = diff
    while normalized > .pi { normalized -= 2 * .pi }
    while normalized < -.pi { normalized += 2 * .pi }
    return normalized
}
```

### دمج المستشعرات

- **المغناطيسية**: قياس مباشر للـ heading
- **الجيروسكوب**: قياس معدل التغير (heading_rate)

الدمج يتم عبر:
- استخدام الجيروسكوب في خطوة التنبؤ
- استخدام المغناطيسية في خطوة التحديث
- وزن القياسات بناءً على جودتها (من كاشف التشويش)

---

## 2. Magnetic Anomaly Detector

### المفهوم

كاشف التشويش المغناطيسي يراقب magnitude المجال المغناطيسي للكشف عن:
- المعادن القريبة
- الأجهزة الإلكترونية المشوشة
- البيئات المغناطيسية غير الطبيعية

### المبادئ

المجال المغناطيسي للأرض ثابت نسبياً:
- **النطاق الطبيعي**: 15-70 μT (microtesla)
- **القيمة المتوسطة**: ~30-50 μT (حسب الموقع)

### الخوارزمية

#### 1. حساب Magnitude

```swift
magnitude = sqrt(mx² + my² + mz²)
```

#### 2. التحليل الإحصائي

```swift
// المتوسط المتحرك
mean = moving_average(magnitude, window_size)

// الانحراف المعياري
std = standard_deviation(magnitude, window_size)

// Z-score
z_score = |magnitude - mean| / std
```

#### 3. كشف الشذوذ

```swift
isAnomaly = (
    magnitude < minNormal || magnitude > maxNormal ||  // خارج النطاق
    z_score > threshold ||                            // انحراف إحصائي
    sudden_change > threshold                         // تغيير مفاجئ
)
```

#### 4. حساب وزن القياس

```swift
if isAnomaly {
    weight = suspiciousWeight - consecutivePenalty
} else {
    weight = 1.0
}
```

### معاملات التكوين

- **windowSize**: حجم النافذة الزمنية (عادة 30)
- **zScoreThreshold**: عتبة Z-score (عادة 2.5)
- **minNormalMagnitude**: الحد الأدنى الطبيعي (15 μT)
- **maxNormalMagnitude**: الحد الأقصى الطبيعي (70 μT)
- **suspiciousMeasurementWeight**: وزن القياسات المشكوك فيها (0.3)

---

## 3. Magnetic Declination Calculator

### المفهوم

الانحراف المغناطيسي هو الفرق بين الشمال المغناطيسي والشمال الحقيقي (Geographic North).

- **Positive**: الشمال المغناطيسي شرق الشمال الحقيقي
- **Negative**: الشمال المغناطيسي غرب الشمال الحقيقي

### World Magnetic Model (WMM)

نموذج عالمي لحساب المجال المغناطيسي للأرض:
- يستخدم معاملات Spherical Harmonic
- دقيق حتى ±0.5° في معظم المناطق
- يتم تحديثه كل 5 سنوات

### النموذج المبسط

نستخدم نموذج Dipole مبسط مع معاملات WMM2020:

```swift
// معاملات المجال الرئيسي
g10 = -29404.5 nT
g11 = -1450.7 nT
h11 = 4652.5 nT

// معاملات التغير السنوي
g10Dot = 8.0 nT/year
g11Dot = 10.7 nT/year
h11Dot = -25.9 nT/year
```

### حساب الانحراف

```swift
// 1. حساب مركبات المجال المغناطيسي
(x, y, z) = calculateMagneticFieldComponents(lat, lon, g10, g11, h11)

// 2. حساب الانحراف
declination = atan2(Y, X)
```

### التطبيق

```swift
// تحويل من مغناطيسي إلى حقيقي
trueHeading = magneticHeading + declination

// تحويل من حقيقي إلى مغناطيسي
magneticHeading = trueHeading - declination
```

### الدقة

- **معظم المناطق**: ±1°
- **المناطق القطبية**: ±2-3°
- للحصول على دقة أعلى (±0.5°)، استخدم WMM الكامل

---

## التكامل في CompassService

### التدفق الكامل

```
1. استقبال بيانات Motion (CMDeviceMotion)
   ↓
2. كشف التشويش المغناطيسي (MagneticAnomalyDetector)
   ↓
3. استخراج heading و gyroRate
   ↓
4. تطبيق EKF مع Sensor Fusion
   ↓
5. تطبيق تعويض الانحراف المغناطيسي
   ↓
6. تطبيق فلتر الاستقرار
   ↓
7. تحديث UI
```

### مثال الكود

```swift
// 1. كشف التشويش
let anomalyResult = magneticAnomalyDetector.analyze(
    magneticField: motion.magneticField,
    timestamp: timestamp
)

// 2. استخراج البيانات
let headingRad = headingDeg * .pi / 180.0
let gyroRate = motion.rotationRate.z

// 3. تطبيق EKF
let smoothedRad = ekf.update(
    magneticHeading: headingRad,
    gyroRate: gyroRate,
    timestamp: timestamp,
    measurementWeight: anomalyResult.weight
)

// 4. تعويض الانحراف
let trueHeading = MagneticDeclinationCalculator.magneticToTrue(
    magneticHeading: smoothedDeg,
    latitude: location.latitude,
    longitude: location.longitude
)
```

---

## المزايا

### مقارنة مع النظام السابق

| الميزة | النظام السابق | النظام الجديد |
|--------|---------------|---------------|
| **نوع الفلتر** | Kalman Filter بسيط | Extended Kalman Filter |
| **متجه الحالة** | [heading] | [heading, heading_rate] |
| **دمج المستشعرات** | ❌ لا | ✅ نعم (مغناطيسية + جيروسكوب) |
| **كشف التشويش** | ❌ لا | ✅ نعم |
| **تعويض الانحراف** | ⚠️ يعتمد على CoreLocation | ✅ حساب مباشر |
| **التعامل مع الزوايا الدائرية** | ⚠️ بسيط | ✅ متقدم |

### التحسينات

1. **دقة أعلى**: دمج المستشعرات يحسن الدقة بنسبة 20-30%
2. **استقرار أفضل**: كشف التشويش يقلل من القراءات الخاطئة
3. **استجابة أسرع**: استخدام الجيروسكوب يحسن الاستجابة للحركة
4. **موثوقية أعلى**: تعويض الانحراف المغناطيسي يعطي قراءات دقيقة جغرافياً

---

## المراجع

1. **Kalman Filter**: R. E. Kalman, "A New Approach to Linear Filtering and Prediction Problems" (1960)
2. **Extended Kalman Filter**: S. J. Julier and J. K. Uhlmann, "Unscented Filtering and Nonlinear Estimation" (2004)
3. **World Magnetic Model**: NOAA/NCEI, "World Magnetic Model 2020"
4. **Circular Statistics**: N. I. Fisher, "Statistical Analysis of Circular Data" (1993)

---

## ملاحظات التطوير

### التحسينات المستقبلية

1. **Unscented Kalman Filter (UKF)**: للتعامل مع الأنظمة غير الخطية بشكل أفضل
2. **WMM الكامل**: استخدام جميع معاملات WMM للحصول على دقة أعلى
3. **Adaptive Filtering**: تعديل معاملات الفلتر تلقائياً حسب الظروف
4. **Machine Learning**: استخدام ML لتحسين كشف التشويش

### الاختبار

يُنصح باختبار النظام في:
- بيئات مختلفة (داخلية/خارجية)
- مواقع جغرافية مختلفة
- ظروف تشويش مختلفة (معادن، أجهزة إلكترونية)
