# ADR-005: Sensor Fusion Engine

**الحالة:** Accepted  
**التاريخ:** 30 يناير 2026  
**المؤلفون:** Knowledge Engineer

---

## السياق

البوصلة تحتاج إلى دمج بيانات من مستشعرات متعددة:
1. **Magnetometer**: يعطي الاتجاه المغناطيسي لكنه حساس للتشويش
2. **Gyroscope**: يعطي معدل الدوران لكنه يعاني من drift
3. **Accelerometer**: يعطي الميلان لكنه حساس للحركة

كل مستشعر بمفرده غير كافٍ. نحتاج دمجهم للحصول على:
- دقة أعلى
- استقرار أفضل
- مقاومة للتشويش

## القرار

نقرر تطبيق **Sensor Fusion Engine** لدمج بيانات المستشعرات المتعددة باستخدام Extended Kalman Filter.

### المميزات الرئيسية:
- **دمج متعدد المستشعرات**: Accelerometer, Gyroscope, Magnetometer
- **EKF للدمج**: استخدام Extended Kalman Filter
- **كشف التشويش التلقائي**: استخدام Magnetic Anomaly Detector
- **تعويض الانحراف**: استخدام Magnetic Declination Calculator

## البدائل المدروسة

### البديل 1: استخدام Magnetometer فقط
**السلبيات:**
- حساس للتشويش المغناطيسي
- لا يعطي معلومات عن الميلان
- دقة محدودة

**الإيجابيات:**
- بسيط
- استهلاك موارد قليل

**القرار:** رُفض - غير كافٍ للدقة المطلوبة

### البديل 2: دمج بسيط (Average)
**السلبيات:**
- لا يأخذ في الاعتبار خصائص كل مستشعر
- لا يتعامل مع الضوضاء بشكل فعال
- لا يستفيد من البيانات الزمنية

**الإيجابيات:**
- بسيط جداً
- سريع

**القرار:** رُفض - غير فعال

### البديل 3: Complementary Filter
**السلبيات:**
- أقل دقة من Kalman Filter
- يحتاج ضبط دقيق للوزن
- لا يتعامل مع الضوضاء بشكل مثالي

**الإيجابيات:**
- أبسط من Kalman Filter
- أسرع
- كافٍ للعديد من التطبيقات

**القرار:** رُفض - غير كافٍ للدقة المطلوبة

### البديل 4: Extended Kalman Filter ✅
**السلبيات:**
- أكثر تعقيداً
- يحتاج حسابات إضافية
- استهلاك موارد أعلى قليلاً

**الإيجابيات:**
- دقة عالية جداً
- دمج فعال للمستشعرات
- معالجة صحيحة للضوضاء
- يتعامل مع الأنظمة غير الخطية

**القرار:** ✅ **مقبول** - أفضل حل للدقة المطلوبة

## العواقب

### الإيجابية
- ✅ **دقة عالية**: دمج فعال لجميع المستشعرات
- ✅ **استقرار**: مقاومة للتشويش والضوضاء
- ✅ **معلومات شاملة**: Roll, Pitch, Yaw + Rates
- ✅ **تكيف ديناميكي**: تعديل بناءً على جودة القياسات
- ✅ **كشف تلقائي**: كشف التشويش تلقائياً

### السلبية
- ⚠️ **تعقيد**: خوارزمية معقدة نسبياً
- ⚠️ **استهلاك موارد**: استهلاك CPU أعلى (~5-10%)
- ⚠️ **ضبط المعاملات**: يحتاج ضبط دقيق
- ⚠️ **صعوبة التصحيح**: يحتاج فهم أعمق

### المحايدة
- 📊 **بيانات إضافية**: توفير معلومات عن جميع المحاور
- 🔧 **قابل للتخصيص**: معاملات قابلة للتعديل

## التنفيذ

### المكونات:
1. **ExtendedKalmanFilter**: الفلتر الرئيسي
2. **MagneticAnomalyDetector**: كشف التشويش
3. **MagneticDeclinationCalculator**: تعويض الانحراف
4. **SensorMeasurement**: هيكل لقياسات المستشعرات

### تدفق البيانات:
```
Accelerometer → EKF ┐
Gyroscope      → EKF ├→ Fused Heading
Magnetometer    → EKF ┘
                      ↓
            Magnetic Anomaly Detector
                      ↓
            Magnetic Declination Calculator
                      ↓
                  Final Heading
```

### الملفات:
- `Moatheny/CompassArchitecture/ExtendedKalmanFilter.swift`
- `Moatheny/MagneticAnomalyDetector.swift`
- `Moatheny/MagneticDeclinationCalculator.swift`
- `Moatheny/CompassService.swift` (التكامل)

## المراجع

- [Sensor Fusion Algorithms](./SensorFusionAlgorithms.md)
- [Multi-Sensor Data Fusion](https://www.researchgate.net/publication/...)
- [Extended Kalman Filter for Attitude Estimation](https://www.researchgate.net/publication/...)

## الملاحظات

- EKF يعمل بكفاءة على iOS
- تم تحسين الأداء باستخدام background queue
- يمكن إضافة تحسينات مثل Adaptive Noise Estimation
- معاملات الضوضاء قابلة للتعديل بناءً على نتائج الاختبارات
