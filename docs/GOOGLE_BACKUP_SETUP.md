# Google Drive Backup Setup — DaynBook

هذه الوثيقة تصف إعدادات المنصة المطلوبة لتشغيل المرحلة الثانية على جهاز Android فعلي. منطق النسخ والتشفير والاستعادة موجود داخل Dart، لكن Google Sign-In يحتاج إعداد OAuth عند إنشاء Android scaffold النهائي.

## الهوية المقترحة للتطبيق

- Application ID: `com.rad03i2.daynbook`
- اسم التطبيق: `DaynBook | دفتر الدين`
- الحد الأدنى المستهدف لـ Android: **API 24 أو أحدث**.

الإصدار الحالي من `google_sign_in_android` يدعم Android SDK 24+، لذلك نعتمد 24 بدل خفض الحد إلى 23.

## Google Cloud

1. أنشئ مشروع Google Cloud خاصًا بـ DaynBook.
2. فعّل **Google Drive API**.
3. جهّز OAuth consent screen.
4. أنشئ OAuth Client من نوع **Android**.
5. استخدم Application ID: `com.rad03i2.daynbook`.
6. أضف SHA-1 لشهادة debug أثناء الاختبار، وSHA-1 لشهادة release قبل النشر.
7. أنشئ أيضًا OAuth Client من نوع **Web application**.
8. استخدم Client ID الخاص بالـWeb client كقيمة `GOOGLE_SERVER_CLIENT_ID` عند التشغيل أو البناء.
9. لا تضع Client Secret أو مفاتيح خاصة داخل GitHub.

DaynBook لا يحتاج Client Secret داخل التطبيق. الكود يقرأ Web OAuth Client ID من `--dart-define` ثم يمرره إلى `GoogleSignIn.initialize(serverClientId: ...)`، وهي طريقة الإعداد المستخدمة عندما لا نعتمد على `google-services.json`.

مثال تشغيل للاختبار:

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

ومثال بناء الإصدار لاحقًا:

```bash
flutter build appbundle --release \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

> يجب أن يتطابق Android OAuth client مع package name وشهادة التوقيع المستخدمة في البناء. اختلاف SHA أو package name من أكثر أسباب فشل Google Sign-In شيوعًا.

## نطاق Google Drive

DaynBook يطلب فقط النطاق:

```text
https://www.googleapis.com/auth/drive.appdata
```

هذا النطاق يسمح للتطبيق بقراءة وإنشاء وحذف بياناته الخاصة في Google Drive ولا يمنحه وصولًا عامًا إلى بقية ملفات المستخدم.

## طريقة النسخ

1. SQLite ينشئ Snapshot منطقيًا متسقًا داخل Transaction.
2. يتم تحويل البيانات إلى JSON.
3. يتم ضغط JSON باستخدام gzip.
4. يُشتق مفتاح 256-bit من عبارة حماية المستخدم باستخدام PBKDF2-HMAC-SHA256.
5. يتم تشفير البيانات بـ AES-256-GCM.
6. يتم حساب SHA-256 للتحقق من سلامة محتوى النسخة.
7. تُرفع النسخة إلى `appDataFolder` في Google Drive.
8. يحتفظ DaynBook بأحدث خمس نسخ ويحذف النسخ الأقدم تلقائيًا.

## عبارة الحماية

- يجب أن تكون 8 أحرف على الأقل؛ ويُفضّل عمليًا استخدام عبارة أطول وفريدة.
- تحفظ على الجهاز باستخدام `flutter_secure_storage` كي يستطيع النسخ التلقائي العمل دون سؤال المستخدم كل ساعة.
- لا تُرفع عبارة الحماية إلى Google Drive.
- عند فقدان الجهاز، يجب على المستخدم إدخال العبارة نفسها على الجهاز الجديد لفك النسخة.
- إذا فُقد الجهاز والعبارة معًا، لا توجد آلية لاسترجاع مفتاح التشفير من Google.

## WorkManager

DaynBook يسجل مهمة دورية باسم:

```text
daynbook-hourly-cloud-backup
```

وتعمل كل ساعة تقريبًا عند:

- وجود اتصال شبكة.
- عدم انخفاض البطارية.
- عدم انخفاض مساحة التخزين.

التوقيت في Android WorkManager غير لحظي؛ النظام قد يؤخر المهمة قليلًا بسبب Doze أو تحسين البطارية. لذلك يوجد أيضًا زر **نسخ الآن** داخل التطبيق.

وفق Quick Start الحالي لحزمة WorkManager `0.10.10`، Android يعمل تلقائيًا ولا يحتاج Custom Application class أو إعداد native إضافي خاص بالحزمة. رغم ذلك يجب اختبار المهمة الدورية على جهاز Android فعلي لأن سياسات البطارية تختلف بين الشركات المصنّعة.

## سلوك Offline-First

أي فشل في:

- Google Sign-In
- صلاحيات Drive
- الإنترنت
- WorkManager
- رفع النسخة

لا يمنع إنشاء زبون أو إضافة دين أو تسديد. SQLite المحلية تبقى مصدر العمل الأساسي، وتظهر حالة النسخ للمستخدم كي يستطيع إعادة المحاولة.

## اختبار الاستعادة قبل الإصدار

قبل بناء النسخة النهائية يجب تنفيذ سيناريو فعلي:

1. إنشاء عدة زبائن وحركات.
2. تنفيذ `نسخ الآن`.
3. التأكد من ظهور النسخة في لوحة الحماية.
4. حذف بيانات التطبيق أو استخدام جهاز/محاكي جديد.
5. تسجيل الدخول بنفس حساب Google.
6. إدخال عبارة الحماية نفسها.
7. استعادة أحدث نسخة.
8. مقارنة عدد الزبائن والحركات والأرصدة قبل وبعد الاستعادة.

لا يُعتبر مسار Disaster Recovery جاهزًا للإصدار قبل نجاح هذا الاختبار على جهاز حقيقي.
