#!/bin/bash

# سكريبت إعداد GitHub Secrets للرفع التلقائي على App Store
# =====================================================

echo "🔐 إعداد GitHub Secrets لتطبيق Moatheny"
echo "========================================"
echo ""

# التحقق من وجود gh CLI
if ! command -v gh &> /dev/null; then
    echo "❌ يجب تثبيت GitHub CLI أولاً:"
    echo "   brew install gh"
    exit 1
fi

# التحقق من تسجيل الدخول
if ! gh auth status &> /dev/null; then
    echo "❌ يجب تسجيل الدخول في GitHub CLI:"
    echo "   gh auth login"
    exit 1
fi

REPO="Hamads85/Moatheny"

echo "📋 الخطوات المطلوبة:"
echo ""
echo "1️⃣  أنشئ App Store Connect API Key:"
echo "   - اذهب إلى: https://appstoreconnect.apple.com/access/integrations/api"
echo "   - انقر 'Generate API Key'"
echo "   - اختر Role: 'Admin' أو 'App Manager'"
echo "   - حمّل ملف .p8"
echo ""

read -p "هل أنشأت الـ API Key؟ (y/n): " created_key

if [[ "$created_key" != "y" ]]; then
    echo "❌ يرجى إنشاء الـ API Key أولاً ثم تشغيل السكريبت مرة أخرى"
    exit 1
fi

echo ""
read -p "📝 أدخل Key ID (مثال: ABC123DEF4): " KEY_ID
read -p "📝 أدخل Issuer ID (مثال: 12345678-1234-1234-1234-123456789012): " ISSUER_ID
read -p "📁 أدخل مسار ملف .p8 (مثال: ~/Downloads/AuthKey_ABC123DEF4.p8): " P8_PATH

# التحقق من وجود الملف
P8_PATH="${P8_PATH/#\~/$HOME}"
if [[ ! -f "$P8_PATH" ]]; then
    echo "❌ الملف غير موجود: $P8_PATH"
    exit 1
fi

echo ""
echo "⏳ جاري إضافة الـ Secrets..."

# تحويل الملف إلى Base64
API_KEY_BASE64=$(base64 -i "$P8_PATH")

# إضافة الـ Secrets
echo "   - إضافة APP_STORE_CONNECT_API_KEY_ID..."
echo "$KEY_ID" | gh secret set APP_STORE_CONNECT_API_KEY_ID --repo "$REPO"

echo "   - إضافة APP_STORE_CONNECT_ISSUER_ID..."
echo "$ISSUER_ID" | gh secret set APP_STORE_CONNECT_ISSUER_ID --repo "$REPO"

echo "   - إضافة APP_STORE_CONNECT_API_KEY_BASE64..."
echo "$API_KEY_BASE64" | gh secret set APP_STORE_CONNECT_API_KEY_BASE64 --repo "$REPO"

echo ""
echo "✅ تم إضافة جميع الـ Secrets بنجاح!"
echo ""
echo "📋 الـ Secrets المضافة:"
gh secret list --repo "$REPO"
echo ""
echo "🚀 الآن يمكنك تشغيل workflow الرفع على App Store:"
echo "   gh workflow run 'Deploy to App Store' --repo $REPO"
