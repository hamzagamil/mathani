# Drafts for mthani.app (T074, T075)

These are for the owner to review. They are **not** in `Mathani-landing` yet. Once approved, add
them to `privacypolicy.html` and `index.html` there and publish with the existing partial deploy
(T078):

```text
node _deploy/netlify-deploy.mjs privacypolicy.html index.html
```

Publish the privacy section before the web app is announced (FR-028).

## Privacy policy: new section "The web app (get.mthani.app)"

### English

Mathani is also available in your browser at https://get.mthani.app. It works like the phone app
and collects nothing about you: no accounts, no analytics, no advertising, no tracking cookies.

- **Your data stays in your browser.** Bookmarks, settings, your reading position, memorization
  results, downloaded recitations and the memorization model are kept by your browser on your
  device, for this site only. They are not sent to us or shared with the phone app. Clearing this
  site's data in your browser deletes them.
- **What your browser downloads, and from where.** Like any website, these servers see your
  device's IP address and the files it asks for, as part of delivering them. We receive no
  reports from them about you.
  - The app and the Mushaf pages come from Cloudflare, which hosts get.mthani.app.
  - The memorization model comes from Hugging Face.
  - Recitations come from the recitation hosts named in the app's About screen (everyayah.com,
    quranicaudio.com and tarteel.ai).
- **The microphone** is used only during a memorization session, after you allow it in your
  browser. Your voice is recognised inside your browser and is never recorded, stored or sent
  anywhere.
- **Storage permission.** Your browser may ask whether this site can keep its data. That
  protects your bookmarks and downloads from being cleared when your device is low on space.

### العربية

يتوفّر مثاني أيضًا في متصفحك على https://get.mthani.app. يعمل مثل تطبيق الهاتف ولا يجمع عنك
أي بيانات: لا حسابات، ولا تحليلات، ولا إعلانات، ولا ملفات تعريف ارتباط للتتبّع.

- **بياناتك تبقى في متصفحك.** تُحفظ علاماتك وإعداداتك وموضع قراءتك ونتائج الحفظ والتلاوات
  التي نزّلتها ونموذج الحفظ في متصفحك على جهازك، لهذا الموقع وحده. لا تُرسل إلينا ولا تُشارك مع
  تطبيق الهاتف. ومسح بيانات هذا الموقع من المتصفح يحذفها.
- **ما ينزّله متصفحك ومن أين.** كأي موقع، ترى هذه الخوادم عنوان IP لجهازك والملفات التي يطلبها
  لتوصيلها إليه. ولا نتلقّى منها أي تقارير عنك.
  - التطبيق وصفحات المصحف من Cloudflare، التي تستضيف get.mthani.app.
  - نموذج الحفظ من Hugging Face.
  - التلاوات من مواقع التلاوات المذكورة في صفحة «عن التطبيق» (everyayah.com و quranicaudio.com
    و tarteel.ai).
- **الميكروفون** يُستخدم في جلسة الحفظ فقط، بعد أن تسمح به في متصفحك. يُتعرَّف على صوتك داخل
  متصفحك، ولا يُسجَّل ولا يُحفظ ولا يُرسل إلى أي مكان.
- **إذن التخزين.** قد يسألك متصفحك إن كان هذا الموقع يستطيع الاحتفاظ ببياناته. يحمي ذلك علاماتك
  وتنزيلاتك من الحذف حين تقلّ المساحة على جهازك.

## Landing page link (FR-002)

Next to the store buttons:

- English: **Open in your browser** → https://get.mthani.app
- العربية: **افتح في المتصفح** ← https://get.mthani.app
