# تصميم تكامل API اتجاه القبلة - Qibla API Integration Design

**التاريخ:** 31 يناير 2026  
**المصمم:** Mobile Architecture Lead

---

## 📋 نظرة عامة

تم تصميم تكامل API اتجاه القبلة من aladhan.com مع دعم caching و fallback للحساب المحلي لضمان:
- ✅ دقة عالية من API عند توفرها
- ✅ عمل بدون إنترنت عبر fallback
- ✅ تقليل استهلاك البيانات عبر caching
- ✅ موثوقية عالية

---

## 🏗️ البنية المعمارية

### 1. APIClient Extension

تم إضافة دالة `fetchQiblaDirection` في `APIClient`:

```swift
func fetchQiblaDirection(latitude: Double, longitude: Double) async throws -> Double
```

**المميزات:**
- Endpoint: `https://api.aladhan.com/v1/qibla/{latitude}/{longitude}`
- Timeout: 15 ثانية (من URLSession configuration)
- Error handling: يرمي `AppError.network` عند الفشل
- Response parsing: يتحقق من `code == 200` و `status == "OK"`
- Normalization: يطبع الزاوية إلى [0, 360]

### 2. QiblaService Enhancement

تم تحديث `QiblaService` لدعم:

#### Dependencies Injection
```swift
init(api: APIClient, cache: LocalCache)
```

#### API Integration with Fallback
```swift
func bearing(from location: CLLocationCoordinate2D) async throws -> Double
```

**الترتيب:**
1. **Check Cache** - التحقق من الكاش أولاً
2. **Try API** - محاولة جلب من API مع timeout 5 ثوانٍ
3. **Local Fallback** - استخدام `calculateLocalBearing()` عند فشل API

#### Caching Strategy

**مدة الصلاحية:** 24 ساعة

**مفتاح الكاش:** 
- يعتمد على الإحداثيات مع تقريب (precision: 0.01 درجة ≈ 1.1 كم)
- Format: `qibla_{latitude}_{longitude}.json`
- مثال: `qibla_24.7100_46.6800.json`

**بنية البيانات:**
```swift
struct CachedQiblaData: Codable {
    let direction: Double
    let latitude: Double
    let longitude: Double
    let timestamp: TimeInterval
}
```

**التحقق:**
- التحقق من صلاحية الكاش (age < 24 hours)
- التحقق من تطابق الإحداثيات (مع هامش خطأ ±0.01 درجة)

#### Local Calculation Fallback

```swift
func calculateLocalBearing(from location: CLLocationCoordinate2D) -> Double
```

- يستخدم Great Circle Bearing Formula
- إحداثيات الكعبة: `21.422487°N, 39.826206°E`
- نفس الخوارزمية المستخدمة سابقاً

---

## 🔄 تدفق البيانات

```
┌─────────────────────────────────────────┐
│         QiblaView (UI Layer)            │
│  updateQibla() → Task { ... }           │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│   QiblaService.bearing()                 │
│  ┌────────────────────────────────────┐ │
│  │ 1. loadCachedDirection()           │ │
│  │    └─> Cache Hit? Return          │ │
│  │                                     │ │
│  │ 2. api.fetchQiblaDirection()       │ │
│  │    └─> Success? Cache & Return    │ │
│  │                                     │ │
│  │ 3. calculateLocalBearing()          │ │
│  │    └─> Fallback Return             │ │
│  └────────────────────────────────────┘ │
└──────────────┬──────────────────────────┘
               │
    ┌──────────┴──────────┐
    │                     │
┌───▼────────┐    ┌───────▼────────┐
│ APIClient  │    │ LocalCache     │
│            │    │                │
│ fetchQibla │    │ store/load     │
│ Direction  │    │ CachedQibla   │
│            │    │ Data           │
└────────────┘    └────────────────┘
```

---

## 📝 التغييرات المطلوبة

### 1. AppContainer Update ✅

```swift
// قبل:
let qibla = QiblaService()

// بعد:
lazy var qibla = QiblaService(api: api, cache: cache)
```

### 2. API Usage (إذا كان هناك استخدام مباشر)

```swift
// قبل:
let direction = qiblaService.bearing(from: location)

// بعد:
let direction = try await qiblaService.bearing(from: location)
```

**ملاحظة:** `QiblaView` حالياً يستخدم `QiblaCalculator.calculateQiblaDirection` مباشرة، لذا لا يحتاج تحديث فوري. لكن يمكن تحديثه لاستخدام `QiblaService.bearing()` للاستفادة من API و caching.

---

## 🧪 الاختبار

### Test Cases المطلوبة:

1. **API Success**
   - جلب اتجاه القبلة من API بنجاح
   - حفظ في الكاش
   - استخدام الكاش في الطلب التالي

2. **API Failure**
   - فشل API → استخدام fallback محلي
   - التحقق من أن النتيجة صحيحة

3. **Cache Hit**
   - استخدام الكاش عند توفر بيانات صالحة
   - تخطي API call

4. **Cache Expiry**
   - حذف الكاش المنتهي الصلاحية
   - جلب بيانات جديدة من API

5. **Offline Mode**
   - عمل بدون إنترنت
   - استخدام fallback محلي فقط

---

## ⚙️ الإعدادات القابلة للتعديل

```swift
// في QiblaService:
private let cacheValidityDuration: TimeInterval = 24 * 60 * 60  // 24 ساعة
private let coordinatePrecision: Double = 0.01                   // ≈ 1.1 كم
```

```swift
// في APIClient:
cfg.timeoutIntervalForRequest = 15  // ثانية
```

```swift
// في QiblaService.bearing():
withTimeout(seconds: 5)  // timeout للـ API call
```

---

## 📊 المقاييس المتوقعة

### الأداء
- **Cache Hit Rate:** ~80-90% (للمستخدمين في نفس الموقع)
- **API Response Time:** ~200-500ms (عند توفر اتصال جيد)
- **Fallback Time:** <10ms (حساب محلي)

### استهلاك البيانات
- **API Call:** ~500 bytes per request
- **Cache Size:** ~100 bytes per location
- **Data Savings:** ~80-90% مع caching

---

## 🔐 الأمان والخصوصية

- ✅ لا يتم إرسال بيانات شخصية للـ API
- ✅ الإحداثيات فقط (latitude, longitude)
- ✅ الكاش محلي على الجهاز فقط
- ✅ لا توجد بيانات حساسة في الكاش

---

## 📚 المراجع

- [ADR-008: Qibla API Integration](./ADRs/ADR-008-Qibla-API-Integration.md)
- [Aladhan API Documentation](https://aladhan.com/qibla-api)
- `PrayerTimeService.swift` - مثال على نمط مشابه
- `AzkarService.swift` - مثال على نمط مشابه

---

## ✅ Checklist

- [x] إضافة `fetchQiblaDirection` في `APIClient`
- [x] تحديث `QiblaService` لدعم API + Cache + Fallback
- [x] تحديث `AppContainer` لتمرير dependencies
- [x] إنشاء ADR لتوثيق القرارات
- [ ] تحديث `QiblaView` لاستخدام `QiblaService.bearing()` (اختياري)
- [ ] إضافة Unit Tests
- [ ] إضافة Integration Tests
