# تقرير المراجعة الأمنية - تطبيق بوصلة القبلة

**التاريخ:** 30 يناير 2026  
**المراجع:** Mobile Security Engineer  
**الإصدار:** 1.0

---

## 📋 الملخص التنفيذي

تم إجراء مراجعة أمنية شاملة لتطبيق iOS للبوصلة. تم اكتشاف **5 ثغرات حرجة** و **8 مشاكل أمنية متوسطة** تتطلب معالجة فورية قبل النشر في الإنتاج.

### الإحصائيات
- **الثغرات الحرجة:** 5
- **المشاكل المتوسطة:** 8
- **التحسينات المقترحة:** 12
- **حالة الأمان:** ⚠️ **غير جاهز للإنتاج**

---

## 🔴 الثغرات الحرجة (Critical)

### 1. تسريب بيانات الموقع في السجلات (Logging)

**الخطورة:** 🔴 Critical  
**الموقع:** `Views.swift:2413`, `LocationService.swift`, `CompassService.swift`

**الوصف:**
يتم طباعة إحداثيات الموقع الدقيقة في سجلات النظام باستخدام `print()`، مما يعرض بيانات المستخدم الحساسة للخطر.

**الكود المتأثر:**
```swift
// Views.swift:2413
print("📍 الموقع: \(loc.coordinate.latitude), \(loc.coordinate.longitude)")

// LocationService.swift:115, 121, 123
print("⚠️ الموقع غير متاح مؤقتاً، جاري المحاولة...")
print("❌ الموقع غير معروف، تأكد من تفعيل GPS")
print("❌ Location error: \(error.localizedDescription)")
```

**التأثير:**
- يمكن للمهاجمين الوصول إلى سجلات التطبيق واستخراج مواقع المستخدمين
- انتهاك خصوصية المستخدم (GDPR/CCPA)
- إمكانية تتبع المستخدمين بناءً على السجلات

**الإصلاح:**
- إزالة جميع `print()` التي تحتوي على بيانات حساسة
- استخدام نظام logging آمن يفلتر البيانات الحساسة
- التأكد من أن DebugFileLogger لا يسجل إحداثيات دقيقة

---

### 2. تخزين بيانات الموقع بدون تشفير

**الخطورة:** 🔴 Critical  
**الموقع:** `LocationService.swift:96-97`, `CityStore.swift:127`

**الوصف:**
يتم حفظ إحداثيات الموقع في `UserDefaults` بدون تشفير، مما يجعلها قابلة للوصول من أي تطبيق على الجهاز (في حالة jailbreak) أو من خلال backups.

**الكود المتأثر:**
```swift
// LocationService.swift:94-98
if let sharedDefaults = UserDefaults(suiteName: "group.com.YourMangaApp.Moatheny") {
    sharedDefaults.set(cityName, forKey: "lastKnownCity")
    sharedDefaults.set(location.coordinate.latitude, forKey: "lastKnownLatitude")
    sharedDefaults.set(location.coordinate.longitude, forKey: "lastKnownLongitude")
    sharedDefaults.synchronize()
}

// CityStore.swift:127-129
if let data = try? JSONEncoder().encode(savedCities) {
    defaults.set(data, forKey: keySavedCities)
}
```

**التأثير:**
- الوصول إلى مواقع المستخدمين من خلال backups غير مشفرة
- إمكانية استخراج البيانات من App Group container
- انتهاك خصوصية المستخدم

**الإصلاح:**
- استخدام `Keychain` لتخزين البيانات الحساسة
- تشفير البيانات قبل حفظها في UserDefaults
- استبعاد البيانات الحساسة من iCloud backups

---

### 3. App Group Security - بيانات غير مشفرة

**الخطورة:** 🔴 Critical  
**الموقع:** `PrayerTimeService.swift:64-73`, `LocationService.swift:94-98`

**الوصف:**
يتم مشاركة بيانات حساسة (إحداثيات الموقع، أوقات الصلاة) عبر App Group بدون تشفير، مما يجعلها قابلة للوصول من أي extension في نفس المجموعة.

**الكود المتأثر:**
```swift
// PrayerTimeService.swift:63-73
guard let sharedDefaults = UserDefaults(suiteName: "group.com.YourMangaApp.Moatheny") else { return }
for prayer in day.prayers {
    sharedDefaults.set(prayer.time, forKey: "prayer_\(prayer.id)")
}
sharedDefaults.set(Date(), forKey: "lastPrayerUpdate")
sharedDefaults.synchronize()
```

**التأثير:**
- أي extension في نفس App Group يمكنه قراءة البيانات
- إمكانية تعديل البيانات من extension خبيث
- تسريب بيانات المستخدم

**الإصلاح:**
- تشفير البيانات قبل مشاركتها عبر App Group
- استخدام Keychain Sharing بدلاً من UserDefaults للبيانات الحساسة
- التحقق من صحة البيانات عند القراءة

---

### 4. Over-permission - طلب Always Authorization بدون مبرر

**الخطورة:** 🔴 Critical  
**الموقع:** `CompassService.swift:144-146`, `CompassService.swift:267`

**الوصف:**
يتم طلب `Always` authorization حتى عندما لا يكون ضرورياً، مما يقلل من ثقة المستخدم ويخالف مبادئ Privacy by Design.

**الكود المتأثر:**
```swift
// CompassService.swift:144-146
if authStatus == .authorizedAlways {
    locationManager.allowsBackgroundLocationUpdates = true
}

// CompassService.swift:267
locationManager.requestAlwaysAuthorization()
```

**التأثير:**
- رفض المستخدمين للتطبيق بسبب طلب أذونات مفرطة
- انتهاك مبادئ Apple Privacy Guidelines
- تقليل معدل الموافقة على الأذونات

**الإصلاح:**
- طلب `WhenInUse` فقط للبوصلة الأساسية
- طلب `Always` فقط عند الحاجة الفعلية (مثل الإشعارات في الخلفية)
- شرح واضح للمستخدم عن سبب الحاجة للأذونات

---

### 5. Background Location Updates بدون التحقق من Authorization

**الخطورة:** 🔴 Critical  
**الموقع:** `CompassService.swift:144-146`, `CompassService.swift:733`

**الوصف:**
يتم تفعيل `allowsBackgroundLocationUpdates` حتى مع `WhenInUse` authorization، مما يخالف سياسات Apple وقد يؤدي إلى رفض التطبيق.

**الكود المتأثر:**
```swift
// CompassService.swift:144-146
if authStatus == .authorizedAlways {
    locationManager.allowsBackgroundLocationUpdates = true
}

// CompassService.swift:733
self.locationManager.allowsBackgroundLocationUpdates = true
```

**التأثير:**
- رفض التطبيق من App Store Review
- انتهاك سياسات Apple Privacy
- استهلاك البطارية بدون مبرر

**الإصلاح:**
- التحقق من `authorizationStatus == .authorizedAlways` قبل تفعيل background updates
- إضافة error handling عند محاولة تفعيل background updates بدون إذن

---

## 🟡 المشاكل المتوسطة (Medium)

### 6. عدم التحقق من صحة بيانات المدخلات

**الخطورة:** 🟡 Medium  
**الموقع:** `CityStore.swift`, `APIClient.swift`

**الوصف:**
لا يتم التحقق من صحة الإحداثيات المدخلة (latitude/longitude) قبل استخدامها، مما قد يؤدي إلى سلوك غير متوقع.

**الإصلاح:**
- التحقق من أن latitude بين -90 و 90
- التحقق من أن longitude بين -180 و 180
- رفض القيم غير الصالحة مع رسالة خطأ واضحة

---

### 7. عدم حماية من Injection Attacks في API URLs

**الخطورة:** 🟡 Medium  
**الموقع:** `APIClient.swift:21`

**الوصف:**
يتم بناء URLs مباشرة من قيم المستخدم بدون encoding مناسب، مما قد يؤدي إلى URL injection.

**الكود المتأثر:**
```swift
guard let url = URL(string: "https://api.aladhan.com/v1/timings/\(ts)?latitude=\(lat)&longitude=\(lon)&method=\(method.rawValue)") else {
```

**الإصلاح:**
- استخدام `URLComponents` و `URLQueryItem` لبناء URLs بشكل آمن
- Encoding مناسب لجميع القيم

---

### 8. عدم حماية من Replay Attacks

**الخطورة:** 🟡 Medium  
**الموقع:** `APIClient.swift`

**الوصف:**
لا يوجد حماية من replay attacks في طلبات API، على الرغم من أن هذا قد لا يكون ضرورياً لهذا التطبيق.

**الإصلاح:**
- إضافة timestamps للطلبات
- التحقق من صحة timestamps في الاستجابات

---

### 9. عدم تنظيف البيانات عند Logout

**الخطورة:** 🟡 Medium  
**الموقع:** لا يوجد logout functionality

**الوصف:**
لا توجد وظيفة logout لمسح البيانات الحساسة عند الحاجة.

**الإصلاح:**
- إضافة وظيفة `clearAllSensitiveData()` لمسح:
  - بيانات الموقع من UserDefaults
  - بيانات الموقع من Keychain
  - بيانات App Group
  - Cache

---

### 10. عدم استبعاد البيانات الحساسة من Backups

**الخطورة:** 🟡 Medium  
**الموقع:** `LocalCache.swift`, `CityStore.swift`

**الوصف:**
لا يتم استبعاد البيانات الحساسة من iCloud/iTunes backups.

**الإصلاح:**
- استخدام `NSURLIsExcludedFromBackupKey` لاستبعاد الملفات الحساسة
- استخدام Keychain للبيانات الحساسة (مستبعدة تلقائياً من backups)

---

### 11. Logging مفرط في Production

**الخطورة:** 🟡 Medium  
**الموقع:** جميع الملفات

**الوصف:**
يتم استخدام `print()` في جميع أنحاء الكود، مما قد يؤدي إلى تسريب معلومات في production builds.

**الإصلاح:**
- استخدام `#if DEBUG` لجميع print statements
- استخدام نظام logging آمن للـ production
- إزالة أو تعطيل DebugFileLogger في production

---

### 12. عدم التحقق من Certificate Pinning

**الخطورة:** 🟡 Medium  
**الموقع:** `APIClient.swift:5-10`

**الوصف:**
لا يوجد certificate pinning لطلبات API، مما يجعل التطبيق عرضة لـ MITM attacks.

**الإصلاح:**
- تطبيق certificate pinning للـ API endpoints
- استخدام `URLSessionDelegate` للتحقق من الشهادات

---

### 13. عدم حماية من Screen Recording

**الخطورة:** 🟡 Low-Medium  
**الموقع:** `Views.swift`

**الوصف:**
لا يتم حماية الشاشات الحساسة من screen recording.

**الإصلاح:**
- استخدام `UIScreen.isCaptured` للكشف عن screen recording
- إخفاء أو تشويش البيانات الحساسة عند الكشف

---

## ✅ نقاط القوة الأمنية

1. ✅ استخدام `DebugFileLogger` مع تعليمات عدم تسجيل PII
2. ✅ استخدام `#if DEBUG` في بعض الأماكن
3. ✅ استخدام App Groups بشكل صحيح للـ Widget
4. ✅ معالجة أخطاء الموقع بشكل مناسب
5. ✅ استخدام `UNUserNotificationCenter` بشكل صحيح

---

## 🔧 التوصيات الأمنية

### أولوية عالية (يجب إصلاحها قبل النشر)

1. **إزالة جميع print() التي تحتوي على بيانات حساسة**
2. **تشفير بيانات الموقع قبل التخزين**
3. **استخدام Keychain للبيانات الحساسة**
4. **إصلاح Over-permission issues**
5. **تطبيق Certificate Pinning**

### أولوية متوسطة (يجب إصلاحها قريباً)

6. **إضافة Input Validation**
7. **استبعاد البيانات الحساسة من Backups**
8. **إضافة وظيفة Logout**
9. **تحسين Error Handling**

### أولوية منخفضة (تحسينات)

10. **إضافة Screen Recording Protection**
11. **تحسين Logging System**
12. **إضافة Security Monitoring**

---

## 📝 خطة العمل

### المرحلة 1: الإصلاحات الحرجة (أسبوع واحد)
- [ ] إزالة print() statements الحساسة
- [ ] تطبيق Keychain Storage
- [ ] إصلاح Over-permission
- [ ] تشفير بيانات App Group

### المرحلة 2: التحسينات المتوسطة (أسبوعين)
- [ ] Input Validation
- [ ] Certificate Pinning
- [ ] Backup Exclusion
- [ ] Logout Functionality

### المرحلة 3: التحسينات (شهر)
- [ ] Screen Recording Protection
- [ ] Security Monitoring
- [ ] Security Testing

---

## 📚 المراجع

- [Apple Security Best Practices](https://developer.apple.com/security/)
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [iOS Privacy Guidelines](https://developer.apple.com/app-store/review/guidelines/#privacy)

---

**تم إعداد التقرير بواسطة:** Mobile Security Engineer  
**التاريخ:** 30 يناير 2026  
**الحالة:** ⚠️ **يتطلب إصلاحات قبل النشر**
