# موذني - Moatheny

تطبيق إسلامي شامل لأوقات الصلاة، القرآن الكريم، الأذكار، واتجاه القبلة.

## المميزات

- **أوقات الصلاة**: حساب دقيق لأوقات الصلاة حسب الموقع
- **القرآن الكريم**: قراءة واستماع مع قراء متعددين
- **الأذكار**: أذكار الصباح والمساء وأذكار متنوعة
- **اتجاه القبلة**: بوصلة دقيقة لتحديد اتجاه القبلة
- **التسبيح**: عداد تسبيح مع إمكانية تخصيص الأهداف
- **Widget**: ودجت لعرض أوقات الصلاة على الشاشة الرئيسية

## المتطلبات

- iOS 17.0+
- Xcode 16.0+
- Swift 5.9+

## التثبيت

1. استنسخ المستودع:
```bash
git clone https://github.com/YOUR_USERNAME/moatheny.git
cd moatheny
```

2. افتح المشروع في Xcode:
```bash
open Moatheny/Moatheny.xcodeproj
```

3. اختر الجهاز أو المحاكي وابنِ المشروع (⌘+B)

## البنية التحتية (AWS Backend)

التطبيق يستخدم AWS لحفظ ومزامنة بيانات المستخدم:

- **Cognito**: مصادقة المستخدمين
- **API Gateway**: REST API
- **Lambda**: معالجة الطلبات
- **DynamoDB**: قاعدة البيانات
- **S3**: تخزين الملفات

### نشر البنية التحتية

```bash
cd aws-backend
sam build
sam deploy --guided
```

## هيكل المشروع

```
moatheny/
├── Moatheny/
│   └── Moatheny/
│       ├── MoathenyApp.swift      # نقطة الدخول
│       ├── Models.swift           # النماذج
│       ├── Views.swift            # الواجهات
│       ├── ViewModels.swift       # ViewModels
│       ├── APIClient.swift        # طبقة الشبكة
│       ├── AuthService.swift      # المصادقة
│       ├── SyncService.swift      # المزامنة
│       ├── PrayerTimeService.swift
│       ├── QuranService.swift
│       ├── AzkarService.swift
│       ├── SimpleCompassService.swift
│       └── Widgets/
├── aws-backend/
│   ├── template.yaml              # SAM template
│   └── lambda/functions/          # Lambda functions
└── .github/workflows/             # CI/CD
```

## APIs المستخدمة

- [Aladhan API](https://aladhan.com/prayer-times-api) - أوقات الصلاة واتجاه القبلة
- [AlQuran Cloud](https://alquran.cloud/api) - نص القرآن
- [Quran.com API](https://api.quran.com) - القراء

## المساهمة

نرحب بالمساهمات! يرجى فتح Issue أو Pull Request.

## الترخيص

جميع الحقوق محفوظة © 2025
