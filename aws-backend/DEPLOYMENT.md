# دليل نشر البنية التحتية - Moatheny Backend

## المتطلبات

1. **AWS CLI** مثبت ومُعَد
2. **AWS SAM CLI** مثبت
3. **Python 3.12**
4. حساب AWS مع صلاحيات كافية

## خطوات النشر

### 1. إعداد OIDC Provider (مرة واحدة فقط)

إذا لم يكن OIDC Provider موجوداً:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 2. إنشاء IAM Role للـ GitHub Actions

```bash
cd aws-backend

aws cloudformation deploy \
  --template-file iam-github-actions.yaml \
  --stack-name moatheny-github-actions-role \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides GitHubOrg=YOUR_GITHUB_USERNAME GitHubRepo=moatheny
```

**استبدل `YOUR_GITHUB_USERNAME` باسم المستخدم الخاص بك على GitHub.**

### 3. نشر البنية التحتية الرئيسية

```bash
cd aws-backend

# بناء التطبيق
sam build --template-file template.yaml

# نشر (أول مرة - سيطلب منك الإعدادات)
sam deploy --guided

# أو نشر مباشر
sam deploy \
  --stack-name moatheny-backend \
  --capabilities CAPABILITY_IAM \
  --region eu-central-1 \
  --resolve-s3
```

### 4. الحصول على معلومات الـ Outputs

بعد النشر، احصل على المعلومات المطلوبة:

```bash
aws cloudformation describe-stacks \
  --stack-name moatheny-backend \
  --query 'Stacks[0].Outputs' \
  --output table
```

ستحصل على:
- **ApiUrl**: رابط API Gateway
- **UserPoolId**: معرف Cognito User Pool
- **UserPoolClientId**: معرف تطبيق Cognito

### 5. تحديث iOS App

افتح الملفات التالية وحدّث القيم:

#### `AuthService.swift`:
```swift
private struct Config {
    static let userPoolId = "eu-central-1_XXXXXXXXX" // من Outputs
    static let clientId = "XXXXXXXXXXXXXXXXXXXXXXXXXX" // من Outputs
    static let region = "eu-central-1"
}
```

#### `SyncService.swift`:
```swift
private struct Config {
    static let apiBaseURL = "https://XXXXXXXXXX.execute-api.eu-central-1.amazonaws.com/prod" // من Outputs
}
```

## التحقق من النشر

### اختبار API

```bash
# اختبار endpoint عام (analytics)
curl -X POST https://YOUR_API_URL/analytics \
  -H "Content-Type: application/json" \
  -d '{"event": "test", "deviceId": "test-device"}'
```

### اختبار Cognito

```bash
# إنشاء مستخدم تجريبي
aws cognito-idp sign-up \
  --client-id YOUR_CLIENT_ID \
  --username test@example.com \
  --password Test1234
```

## إعداد GitHub Repository

### 1. رفع الكود

```bash
cd /Users/hamads/Documents/moatheny
git remote add origin https://github.com/YOUR_USERNAME/moatheny.git
git push -u origin main
```

### 2. التحقق من Workflows

بعد رفع الكود، تحقق من:
- **Actions tab** في GitHub
- CI يعمل على Pull Requests
- CD يعمل عند push إلى `aws-backend/`

## حذف البنية التحتية (إذا لزم الأمر)

```bash
# حذف Stack الرئيسي
aws cloudformation delete-stack --stack-name moatheny-backend

# حذف IAM Role
aws cloudformation delete-stack --stack-name moatheny-github-actions-role
```

## استكشاف الأخطاء

### خطأ في SAM Deploy
```bash
# تنظيف وإعادة البناء
rm -rf .aws-sam
sam build --use-container
sam deploy
```

### خطأ في Lambda
```bash
# عرض السجلات
aws logs tail /aws/lambda/moatheny-backend-GetSettingsFunction --follow
```

### خطأ في Cognito
```bash
# عرض تفاصيل User Pool
aws cognito-idp describe-user-pool --user-pool-id YOUR_POOL_ID
```

## التكلفة المتوقعة

| الخدمة | التكلفة الشهرية |
|--------|-----------------|
| DynamoDB | ~$0 (Pay-per-request) |
| Lambda | ~$0 (1M طلب مجاني) |
| API Gateway | ~$0 (1M طلب مجاني) |
| Cognito | ~$0 (50K مستخدم مجاني) |
| **المجموع** | **$0-5/شهر** |
