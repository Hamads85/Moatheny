# إعداد GitHub Secrets للرفع التلقائي على App Store

## الخطوة 1: إنشاء App Store Connect API Key

1. اذهب إلى [App Store Connect](https://appstoreconnect.apple.com)
2. انقر على **Users and Access** → **Integrations** → **App Store Connect API**
3. انقر على **Generate API Key**
4. اختر **Admin** أو **App Manager** كـ Role
5. حمّل الملف `.p8` واحفظ:
   - **Key ID** (مثال: `ABC123DEF4`)
   - **Issuer ID** (مثال: `12345678-1234-1234-1234-123456789012`)

## الخطوة 2: تصدير Distribution Certificate

### من Xcode:
1. افتح **Xcode** → **Settings** → **Accounts**
2. اختر حسابك → **Manage Certificates**
3. إذا لم يكن لديك **Apple Distribution** certificate:
   - انقر على **+** → **Apple Distribution**
4. افتح **Keychain Access**
5. ابحث عن **Apple Distribution** certificate
6. انقر بالزر الأيمن → **Export**
7. احفظه كـ `.p12` مع كلمة مرور

## الخطوة 3: تحميل Provisioning Profile

1. اذهب إلى [Apple Developer Portal](https://developer.apple.com/account/resources/profiles/list)
2. أنشئ **App Store** provisioning profile لـ `com.YourMangaApp.Moatheny`
3. حمّل الملف `.mobileprovision`

## الخطوة 4: تحويل الملفات إلى Base64

شغّل هذه الأوامر في Terminal:

```bash
# تحويل Certificate
base64 -i ~/path/to/certificate.p12 | pbcopy
# الصق في GitHub Secret: BUILD_CERTIFICATE_BASE64

# تحويل Provisioning Profile
base64 -i ~/path/to/profile.mobileprovision | pbcopy
# الصق في GitHub Secret: PROVISIONING_PROFILE_BASE64

# تحويل API Key
base64 -i ~/path/to/AuthKey_XXXXXX.p8 | pbcopy
# الصق في GitHub Secret: APP_STORE_CONNECT_API_KEY_BASE64
```

## الخطوة 5: إضافة Secrets في GitHub

1. اذهب إلى: https://github.com/Hamads85/Moatheny/settings/secrets/actions
2. أضف هذه الـ Secrets:

| Secret Name | القيمة |
|-------------|--------|
| `BUILD_CERTIFICATE_BASE64` | محتوى الـ .p12 بعد تحويله لـ Base64 |
| `P12_PASSWORD` | كلمة مرور الـ .p12 |
| `KEYCHAIN_PASSWORD` | أي كلمة مرور (مثال: `temp123`) |
| `PROVISIONING_PROFILE_BASE64` | محتوى الـ .mobileprovision بعد تحويله |
| `APP_STORE_CONNECT_API_KEY_ID` | الـ Key ID من الخطوة 1 |
| `APP_STORE_CONNECT_ISSUER_ID` | الـ Issuer ID من الخطوة 1 |
| `APP_STORE_CONNECT_API_KEY_BASE64` | محتوى الـ .p8 بعد تحويله |

## الخطوة 6: اختبار

بعد إضافة جميع الـ Secrets:
1. اذهب إلى **Actions** في GitHub
2. اختر **Deploy to App Store**
3. انقر **Run workflow**

---

## ملاحظات مهمة:
- الـ Distribution Certificate يختلف عن Development Certificate
- تأكد من أن الـ Provisioning Profile من نوع **App Store** وليس Development
- الـ API Key يجب أن يكون له صلاحيات كافية (Admin أو App Manager)
