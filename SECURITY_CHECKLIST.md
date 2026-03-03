# Security Checklist - تطبيق بوصلة القبلة

## ✅ Checklist سريع للمطورين

### 🔴 حرجة - يجب إصلاحها قبل النشر

- [ ] **إزالة جميع print() الحساسة**
  - [ ] البحث عن `print(` في جميع الملفات
  - [ ] إزالة أو تعطيل print() التي تحتوي على:
    - [ ] `latitude`
    - [ ] `longitude`
    - [ ] `coordinate`
    - [ ] `location`
    - [ ] أي بيانات حساسة أخرى

- [ ] **تطبيق Secure Storage (Keychain)**
  - [ ] إنشاء `SecureStorageService` (راجع SECURITY_FIXES.md)
  - [ ] استبدال `UserDefaults` بـ Keychain للبيانات الحساسة:
    - [ ] إحداثيات الموقع
    - [ ] أي tokens أو secrets
  - [ ] اختبار حفظ وقراءة البيانات

- [ ] **إصلاح Over-permission**
  - [ ] تعديل `CompassService.swift`:
    - [ ] طلب `WhenInUse` فقط للبوصلة الأساسية
    - [ ] طلب `Always` فقط عند الحاجة الفعلية
  - [ ] التحقق من `authorizationStatus` قبل تفعيل background updates
  - [ ] اختبار الأذونات

- [ ] **تشفير بيانات App Group**
  - [ ] تشفير البيانات قبل حفظها في App Group
  - [ ] استخدام Keychain Sharing بدلاً من UserDefaults للبيانات الحساسة
  - [ ] اختبار مشاركة البيانات مع Widget

- [ ] **تطبيق Certificate Pinning**
  - [ ] إنشاء `CertificatePinningDelegate` (راجع SECURITY_FIXES.md)
  - [ ] إضافة SHA-256 fingerprints للشهادات المسموحة
  - [ ] تطبيق على جميع API endpoints
  - [ ] اختبار MITM protection

### 🟡 متوسطة - يجب إصلاحها قريباً

- [ ] **Input Validation**
  - [ ] إنشاء `LocationValidator` (راجع SECURITY_FIXES.md)
  - [ ] التحقق من صحة الإحداثيات قبل الاستخدام:
    - [ ] `latitude` بين -90 و 90
    - [ ] `longitude` بين -180 و 180
  - [ ] رفض القيم غير الصالحة مع رسالة خطأ

- [ ] **Backup Exclusion**
  - [ ] استبعاد الملفات الحساسة من backups
  - [ ] استخدام `isExcludedFromBackup` للملفات
  - [ ] استخدام Keychain (مستبعد تلقائياً)

- [ ] **Logout Functionality**
  - [ ] إنشاء `SecurityManager.clearAllSensitiveData()`
  - [ ] مسح:
    - [ ] Keychain
    - [ ] UserDefaults
    - [ ] App Group data
    - [ ] Cache files
  - [ ] اختبار وظيفة Logout

- [ ] **تحسين Error Handling**
  - [ ] إزالة print() من error handlers
  - [ ] استخدام SecureLogger للـ errors
  - [ ] عدم تسريب معلومات حساسة في error messages

### 🟢 منخفضة - تحسينات

- [ ] **Screen Recording Protection**
  - [ ] استخدام `UIScreen.isCaptured` للكشف
  - [ ] إخفاء أو تشويش البيانات الحساسة عند الكشف

- [ ] **Security Monitoring**
  - [ ] إضافة logging للـ security events
  - [ ] مراقبة محاولات الوصول غير المصرح بها

- [ ] **Security Testing**
  - [ ] اختبار جميع الإصلاحات
  - [ ] اختبار الأذونات
  - [ ] اختبار التخزين الآمن
  - [ ] اختبار Certificate Pinning

---

## 🔍 فحص سريع قبل Commit

قبل كل commit، تأكد من:

- [ ] لا توجد `print()` تحتوي على بيانات حساسة
- [ ] جميع البيانات الحساسة محفوظة في Keychain
- [ ] لا يتم طلب أذونات غير ضرورية
- [ ] جميع API calls محمية بـ Certificate Pinning
- [ ] تم التحقق من صحة جميع المدخلات

---

## 📝 ملاحظات مهمة

1. **لا تستخدم `print()` للبيانات الحساسة أبداً**
   - استخدم `SecureLogger` أو `DebugFileLogger` فقط
   - تأكد من أن logging لا يحتوي على بيانات حساسة

2. **استخدم Keychain دائماً للبيانات الحساسة**
   - إحداثيات الموقع
   - Tokens
   - Secrets
   - أي بيانات شخصية

3. **اطلب الأذونات بشكل تدريجي**
   - ابدأ بـ `WhenInUse`
   - اطلب `Always` فقط عند الحاجة الفعلية
   - اشرح للمستخدم سبب الحاجة للأذونات

4. **اختبر جميع الإصلاحات**
   - قبل النشر
   - على أجهزة مختلفة
   - في سيناريوهات مختلفة

---

## 🚨 علامات خطر

إذا رأيت أي من التالي، توقف ومراجعة الأمان:

- ❌ `print()` يحتوي على `latitude` أو `longitude`
- ❌ حفظ بيانات حساسة في `UserDefaults`
- ❌ طلب `Always` authorization بدون مبرر
- ❌ تفعيل `allowsBackgroundLocationUpdates` بدون التحقق من authorization
- ❌ عدم وجود Certificate Pinning للـ API calls
- ❌ عدم التحقق من صحة المدخلات

---

## 📚 المراجع السريعة

- **التقرير الكامل:** `SECURITY_REVIEW_REPORT.md`
- **الكود المحسّن:** `SECURITY_FIXES.md`
- **الملخص:** `SECURITY_SUMMARY_AR.md`

---

**آخر تحديث:** 30 يناير 2026
