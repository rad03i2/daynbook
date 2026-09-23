# Google Drive Backup Setup — DaynBook

هذه الوثيقة تثبّت إعداد Google OAuth المطلوب لتجربة النسخ والاستعادة على Android، مع فصل هوية الاختبار عن هوية الإنتاج.

## هويات Android

### نسخة التطوير والاختبار الحالية

- Package / Application ID: `com.rad03i2.daynbook.dev`
- اسم التطبيق الظاهر: `دفتر الدين DEV`
- minSdk: **API 24**
- شهادة التطوير ثابتة ومخصصة لهذه الحزمة فقط.
- SHA-1:

```text
DC:D6:B6:FE:DF:0E:82:A4:01:9D:3F:5D:71:5D:2A:FD:F8:15:16:08
```

- SHA-256:

```text
93:0D:7D:A5:B7:99:04:A7:EA:7F:BF:DB:CA:3A:C7:BA:61:CD:F0:CF:29:78:3E:51:33:EF:D6:36:6D:5A:59:C7
```

هذه الشهادة **ليست مفتاح إصدار Production**. وجودها في المستودع مقصود لأنها توقع حزمة `.dev` فقط، لتثبيت بصمة OAuth أثناء الاختبارات. لا يجوز استخدامها لتوقيع `com.rad03i2.daynbook` النهائي.

### هوية الإنتاج لاحقًا

- Package / Application ID: `com.rad03i2.daynbook`
- تحتاج مفتاح Release خاصًا غير منشور في GitHub.
- عند النشر عبر Google Play يجب تسجيل SHA الخاص بمفتاح App Signing الذي يستخدمه Google Play للإصدار الموزع.

## إعداد Google Cloud / Google Auth Platform للاختبار

1. أنشئ أو اختر مشروع Google Cloud باسم مناسب لـDaynBook.
2. فعّل **Google Drive API**.
3. افتح **Google Auth Platform** واضبط Branding وAudience وData Access.
4. إذا كان الحساب شخصيًا أو التطبيق سيستخدم خارج Google Workspace، استخدم جمهور **External** وأضف حساب الاختبار ضمن Test users أثناء وضع الاختبار.
5. أضف نطاق Drive الذي يحتاجه التطبيق:

```text
https://www.googleapis.com/auth/drive.appdata
```

6. أنشئ OAuth Client من نوع **Android** بالقيم التالية بالضبط:

```text
Package name: com.rad03i2.daynbook.dev
SHA-1: DC:D6:B6:FE:DF:0E:82:A4:01:9D:3F:5D:71:5D:2A:FD:F8:15:16:08
```

7. أنشئ OAuth Client آخر من نوع **Web application**.
8. انسخ **Client ID** الخاص بالـWeb client. DaynBook يستخدمه كـ`serverClientId`. لا يتم تضمين Client Secret في تطبيق Android.

## تمرير Web Client ID إلى DaynBook

الكود يقرأ القيمة من Dart define:

```bash
flutter run \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

وفي GitHub Actions يمكن وضع Web Client ID في Repository Secret باسم:

```text
GOOGLE_SERVER_CLIENT_ID
```

ثم يبنيه Workflow تلقائيًا داخل APK التجريبي. الـClient ID نفسه ليس كلمة مرور، لكن إبقاء الإعداد في Actions يجعل تبديله أسهل بدون تعديل الكود.

## لماذا يوجد Android Client وWeb Client؟

Android OAuth Client يثبت أن طلب تسجيل الدخول صادر من الحزمة الصحيحة وشهادة التوقيع الصحيحة. أما `google_sign_in` على Android فعند عدم استخدام `google-services.json` يحتاج Web OAuth Client ID كـ`serverClientId` أثناء `GoogleSignIn.initialize(...)`.

## نطاق Google Drive

DaynBook يطلب فقط:

```text
https://www.googleapis.com/auth/drive.appdata
```

وتُحفظ النسخ داخل `appDataFolder` الخاصة بالتطبيق، وليس ضمن ملفات Drive العادية التي يتصفحها المستخدم.

## طريقة النسخ

1. إنشاء Snapshot منطقي متناسق من SQLite داخل Transaction.
2. تحويل البيانات إلى JSON ثم ضغطها بـgzip.
3. اشتقاق مفتاح 256-bit من عبارة الحماية باستخدام PBKDF2-HMAC-SHA256.
4. تشفير النسخة بـAES-256-GCM.
5. حساب SHA-256 للتحقق من سلامة المحتوى.
6. رفع النسخة إلى `appDataFolder`.
7. الاحتفاظ بأحدث خمس نسخ وحذف الأقدم تلقائيًا.

## التخزين الآمن وAndroid Auto Backup

DaynBook يخزن عبارة الحماية محليًا باستخدام `flutter_secure_storage`. تم تعطيل Android OS Auto Backup (`android:allowBackup="false"`) حتى لا يستعيد النظام بيانات Secure Storage على جهاز آخر بدون مفتاح Android Keystore الأصلي. النسخ والاستعادة في DaynBook يجب أن تتم من خلال نظام النسخ المشفر الخاص بالتطبيق فقط.

## WorkManager

المهمة الدورية المسجلة:

```text
daynbook-hourly-cloud-backup
```

وتعمل كل ساعة تقريبًا عند توفر الشبكة وعدم انخفاض البطارية أو التخزين. Android قد يؤخر المهمة بسبب Doze وسياسات الشركات المصنّعة؛ لذلك يبقى زر **نسخ الآن** متاحًا دائمًا.

## اختبار Disaster Recovery المطلوب

بعد إنشاء OAuth clients وإعادة بناء APK مع `GOOGLE_SERVER_CLIENT_ID`:

1. ثبّت `دفتر الدين DEV`.
2. سجّل الدخول بحساب Google المضاف كـTest user.
3. عيّن عبارة حماية واحفظها خارج الجهاز مؤقتًا للاختبار.
4. أنشئ عدة زبائن وحركات دين وتسديد.
5. نفّذ **نسخ الآن** وتأكد من ظهور النسخة السحابية.
6. دوّن أعداد الزبائن والحركات وبعض الأرصدة.
7. امسح بيانات التطبيق بالكامل أو ثبته على جهاز/محاكي آخر.
8. سجّل الدخول بالحساب نفسه.
9. أدخل عبارة الحماية نفسها.
10. استعد أحدث نسخة.
11. قارن الزبائن والحركات والأرصدة قبل وبعد الاستعادة.

لا تُغلق مرحلة Disaster Recovery قبل نجاح هذا السيناريو فعليًا على Android.
