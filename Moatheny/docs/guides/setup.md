# Setup Instructions - Compass Development

## المتطلبات

### الأدوات
- **Xcode**: 15.0 أو أحدث
- **iOS SDK**: iOS 16.0 أو أحدث
- **Swift**: 5.9 أو أحدث
- **macOS**: 13.0 (Ventura) أو أحدث

### الأجهزة
- جهاز iOS حقيقي (مُوصى به للاختبار)
- أو iOS Simulator (مع قيود على المستشعرات)

## الإعداد الأولي

### 1. Clone المشروع

```bash
git clone https://github.com/your-org/moatheny.git
cd moatheny/Moatheny
```

### 2. فتح المشروع في Xcode

```bash
open Moatheny.xcodeproj
```

### 3. إعداد Signing & Capabilities

1. اختر Target: **Moatheny**
2. اذهب إلى **Signing & Capabilities**
3. اختر **Team** الخاص بك
4. تأكد من تفعيل Capabilities:
   - ✅ Location Services
   - ✅ Background Modes (Location updates)

### 4. إعداد Info.plist

تأكد من وجود المفاتيح التالية في `Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>نحتاج موقعك لحساب أوقات الصلاة واتجاه القبلة بدقة</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>للحصول على دقة عالية في البوصلة، نحتاج إذن الموقع دائماً</string>

<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>
```

## البنية

### هيكل الملفات

```
Moatheny/
├── Moatheny/
│   ├── CompassService.swift              # الخدمة الرئيسية
│   ├── CompassArchitecture/
│   │   ├── ExtendedKalmanFilter.swift   # EKF
│   │   ├── MagneticInterferenceDetector.swift
│   │   ├── MagneticDeclinationService.swift
│   │   └── CalibrationManager.swift
│   ├── ExtendedKalmanFilter.swift       # EKF (التكامل)
│   ├── MagneticAnomalyDetector.swift    # كاشف التشويش
│   ├── MagneticDeclinationCalculator.swift
│   ├── PerformanceMetricsCollector.swift
│   ├── AdaptiveUpdateRateManager.swift
│   └── ...
├── docs/                                 # الوثائق
└── Tests/                                # الاختبارات
```

## التطوير

### 1. إنشاء Branch جديد

```bash
git checkout -b feature/your-feature-name
```

### 2. التطوير

- اتبع [Coding Standards](../reference/standards.md)
- اكتب Tests للكود الجديد
- راجع [API Documentation](../api/interfaces.md)

### 3. الاختبار

```bash
# تشغيل جميع الاختبارات
cmd+U في Xcode

# أو من Terminal
xcodebuild test -scheme Moatheny -destination 'platform=iOS Simulator,name=iPhone 15'
```

### 4. Commit

```bash
git add .
git commit -m "feat: وصف التغيير"
```

### 5. Push

```bash
git push origin feature/your-feature-name
```

## الاختبار على جهاز حقيقي

### 1. توصيل الجهاز

- وصّل iPhone/iPad بـ USB
- ثق في الكمبيوتر عند الطلب

### 2. اختيار الجهاز في Xcode

- اختر الجهاز من قائمة الأجهزة
- اضغط Run (⌘R)

### 3. منح الأذونات

عند أول تشغيل:
- ✅ امنح إذن الموقع
- ✅ امنح إذن الإشعارات (إذا لزم)

## Debugging

### تفعيل Debug Logging

```swift
// في CompassService.swift:
private var isDebugLoggingEnabled = true
```

### استخدام Debug Overlay

```swift
// في QiblaView:
// اضغط 3 مرات على الشاشة لإظهار Debug Overlay
.onTapGesture(count: 3) {
    showDebug.toggle()
}
```

### استخدام Instruments

1. اختر **Product > Profile** (⌘I)
2. اختر **Time Profiler** أو **Allocations**
3. شغّل التطبيق
4. راجع النتائج

## Troubleshooting

### المشكلة: البوصلة لا تعمل في Simulator

**الحل:** Simulator لا يدعم المستشعرات بشكل كامل. استخدم جهاز حقيقي للاختبار.

### المشكلة: إذن الموقع مرفوض

**الحل:**
1. اذهب إلى Settings > Privacy & Security > Location Services
2. فعّل Location Services
3. ابحث عن Moatheny واختر "While Using the App"

### المشكلة: Build Errors

**الحل:**
1. نظف Build Folder: **Product > Clean Build Folder** (⇧⌘K)
2. أعد فتح Xcode
3. تأكد من تحديث Dependencies

## المراجع

- [Contribution Guidelines](./contributing.md)
- [Testing Guide](./testing.md)
- [API Documentation](../api/interfaces.md)
