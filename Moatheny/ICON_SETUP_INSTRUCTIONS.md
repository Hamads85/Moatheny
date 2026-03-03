# تعليمات إضافة أيقونة التطبيق - App Icon Setup

## ⚠️ مطلوب: إضافة أيقونات التطبيق

رفض App Store التطبيق لأن الأيقونات مفقودة. يجب إضافة الأيقونات التالية:

---

## الطريقة الأولى: استخدام أيقونة واحدة 1024x1024 (الأسهل)

### 1. تصميم أيقونة واحدة:
- الحجم: **1024×1024 بكسل**
- الصيغة: **PNG**
- بدون شفافية (خلفية ملونة)
- تصميم إسلامي (مثلاً: هلال، مسجد، قرآن، إلخ)

### 2. استخدام موقع لتوليد جميع الأحجام تلقائياً:

**الموقع المقترح:**
- https://www.appicon.co (مجاني)
- https://appicon.build (مجاني)
- https://makeappicon.com (مجاني)

**الخطوات:**
1. ارفع أيقونتك 1024×1024
2. حمّل ملف ZIP يحتوي على جميع الأحجام
3. فك الضغط
4. اسحب الملفات إلى Xcode (الطريقة أدناه)

---

## الطريقة الثانية: إضافة الأيقونات في Xcode مباشرة

### 1. في Xcode، افتح:
```
Moatheny → Assets.xcassets → AppIcon
```

### 2. ستجد الخانات التالية (اسحب الأيقونات إليها):

| الخانة | الحجم المطلوب | اسم الملف |
|--------|---------------|-----------|
| **iPhone Notification 2x** | 40×40 | Icon-40@2x.png |
| **iPhone Notification 3x** | 60×60 | Icon-60@3x.png |
| **iPhone Settings 2x** | 58×58 | Icon-58@2x.png |
| **iPhone Settings 3x** | 87×87 | Icon-87@3x.png |
| **iPhone Spotlight 2x** | 80×80 | Icon-80@2x.png |
| **iPhone Spotlight 3x** | 120×120 | Icon-120@3x.png |
| **iPhone App 2x** | 120×120 | Icon-60@2x.png |
| **iPhone App 3x** | 180×180 | Icon-60@3x.png |
| **iPad Notifications 1x** | 20×20 | Icon-20.png |
| **iPad Notifications 2x** | 40×40 | Icon-40@2x.png |
| **iPad Settings 1x** | 29×29 | Icon-29.png |
| **iPad Settings 2x** | 58×58 | Icon-58@2x.png |
| **iPad Spotlight 1x** | 40×40 | Icon-40.png |
| **iPad Spotlight 2x** | 80×80 | Icon-80@2x.png |
| **iPad App 1x** | 76×76 | Icon-76.png |
| **iPad App 2x** | 152×152 | Icon-76@2x.png |
| **iPad Pro 2x** | 167×167 | Icon-83.5@2x.png |
| **App Store** | 1024×1024 | Icon-1024.png |

---

## الطريقة الثالثة: طلب تصميم جاهز

### مواقع أيقونات إسلامية مجانية:
- **Flaticon**: https://www.flaticon.com/search?word=mosque&type=icon
- **Icons8**: https://icons8.com/icons/set/mosque
- **IconFinder**: https://www.iconfinder.com/search?q=islamic

### تصاميم مقترحة للتطبيق:
- 🕌 مسجد مع هلال
- 📖 مصحف مفتوح
- 🌙 هلال إسلامي
- ☪️ هلال ونجمة (رمز إسلامي)

---

## الخطوات السريعة (استخدام AppIcon.co):

### 1. تصميم سريع أو تحميل أيقونة:
```bash
# يمكنك استخدام هذا الأمر لإنشاء أيقونة بسيطة (macOS):
# سيفتح Preview - ارسم أيقونة بسيطة أو اكتب نص
open -a Preview
```

### 2. اذهب إلى AppIcon.co:
- رابط مباشر: https://www.appicon.co
- ارفع أيقونة 1024×1024 (أو حتى أصغر - الموقع يكبّرها)
- اختر "iOS" و "All Sizes"
- اضغط "Generate"
- حمّل ملف ZIP

### 3. في Xcode:
1. فك ضغط ملف ZIP
2. افتح `Assets.xcassets` → `AppIcon`
3. اسحب جميع ملفات PNG من المجلد `ios/` إلى الخانات المناسبة
4. أو: احذف `AppIcon` القديم واسحب `AppIcon.appiconset` الجديد كاملاً

### 4. تحقق من الإعدادات:
- Xcode → Target "Moatheny" → Build Settings
- ابحث عن "App Icon" أو `ASSETCATALOG_COMPILER_APPICON_NAME`
- تأكد أنها = `AppIcon`

### 5. أعد البناء والتحميل:
```
Product → Clean Build Folder (⇧⌘K)
Product → Archive
```

---

## الحل السريع جداً: أيقونة تجريبية

إذا كنت تريد فقط اختبار الرفع بسرعة:

### استخدم أيقونة تجريبية جاهزة:
1. اذهب إلى: https://icon.kitchen
2. اختر "Text Icon"
3. اكتب: "م" (أول حرف من مؤذني) أو "🕌"
4. اختر ألوان إسلامية (أخضر، ذهبي)
5. حمّل جميع الأحجام
6. أضفها في Xcode

---

## التحقق من الإصلاح:

بعد إضافة الأيقونات:

1. **افتح Navigator → Project → Moatheny target → General**
2. تحت "App Icons and Launch Screen"، تأكد من اختيار `AppIcon`
3. يجب أن ترى الأيقونة معروضة
4. **Build Settings** → ابحث `CFBundleIconName` → يجب أن تكون = `AppIcon`

---

## ملاحظات مهمة:

✅ **تم الإصلاح في الكود:**
- أضفت `INFOPLIST_KEY_CFBundleIconName = AppIcon` في build settings
- حدّثت `Contents.json` لتطلب جميع الأحجام المطلوبة

⚠️ **يبقى عليك:**
- تصميم/تحميل أيقونة التطبيق
- إضافة ملفات PNG للأحجام المطلوبة في `Assets.xcassets/AppIcon.appiconset/`

---

## الأحجام المطلوبة بالضبط (للنسخ اليدوي):

```
Icon-60@2x.png     → 120×120 (iPhone App)
Icon-60@3x.png     → 180×180 (iPhone App)
Icon-76.png        → 76×76 (iPad App)
Icon-76@2x.png     → 152×152 (iPad App)
Icon-83.5@2x.png   → 167×167 (iPad Pro)
Icon-1024.png      → 1024×1024 (App Store)
```

**الأهم:**
- `Icon-60@2x.png` = **120×120** ← هذا ما يطلبه الخطأ الأول
- `Icon-76@2x.png` = **152×152** ← هذا ما يطلبه الخطأ الثاني
- `Icon-1024.png` = **1024×1024** ← مطلوب دائماً

---

بعد إضافة الأيقونات، أعد:
```
Product → Clean Build Folder
Product → Archive
Window → Organizer → Distribute App
```

الآن سينجح الرفع! 🎉

