# Galaxy Store listing: Gulf Limousine

Everything to paste into the Samsung Galaxy Store Seller Portal
(<https://seller.samsungapps.com>). Account and app registration are free.

## Files in this folder

| Item | File | Store requirement |
|---|---|---|
| App binary | `gulf-limousine-1.0.5.apk` (not in git, see below) | APK, signed |
| Icon | `icon_512.png` | 512 × 512 PNG |
| Screenshots, English | `screenshots/en/01…07.png` | 4 to 8, 1080 × 1920 |
| Screenshots, Arabic | `screenshots/ar/01…07.png` | 4 to 8, 1080 × 1920 |

The APK is version **1.0.5 (build 6)**, package `com.gulflimousine.travel.app`,
signed with the Play release key (the same key works for Google Play later).
Build it with `flutter build apk --release`; the file is
`build/app/outputs/flutter-apk/app-release.apk`.

## App information

| Field | Value |
|---|---|
| App title | Gulf Limousine |
| Default language | English (add Arabic as a second language) |
| Category | Travel (or Travel & Local) |
| Price | Free |
| Countries | Egypt (add others if you want) |
| Age rating | Everyone / 3+ (no violence, no gambling, no user-generated public content) |
| Privacy policy URL | https://gulf-limousine-travel-1d4c7.web.app/privacy.html |
| Support email | info@gulflimousine.com (use an address you actually read) |
| Support phone | +20 100 111 6666 |
| Website | https://gulf-limousine-travel-1d4c7.web.app |

## English

**Short description (up to 80 characters)**

Rent luxury cars in Cairo: choose dates, colours and pay your way.

**Description**

Gulf Limousine Travel lets you rent a car in Cairo in a few taps.

• Browse the fleet with prices, seats, fuel type and ratings.
• Pick your dates and see how many cars of each model are free.
• Rent several cars of the same model and rank colours by preference.
• Choose pickup and drop-off points on the map.
• Pay by card or mobile wallet online, by InstaPay or wallet transfer, or in cash when you collect the car.
• Sign the rental agreement in the app.
• Track your chauffeur, record the odometer and the car's condition at pickup and return.
• Get notified when your booking is confirmed or your trip changes.
• Ask the AI assistant about cars, bookings and payments.
• Full Arabic and English, with fingerprint or Face ID login.

Your data stays private: see our privacy policy. You can delete your account at any time from Profile.

**What's new (1.0.5)**

Call, email and WhatsApp buttons now work reliably, and InstaPay opens directly. Fixed sign-in for passwords with spaces, clearer messages when a photo upload fails, up-to-date prices when booking from Favorites, and other booking fixes.

**Keywords / tags**

car rental, Cairo, limousine, chauffeur, Egypt, rent a car, InstaPay, luxury cars

## العربية

**الوصف المختصر**

استأجر سيارات فاخرة في القاهرة: اختر التواريخ والألوان وادفع بطريقتك.

**الوصف**

جلف ليموزين ترافل تتيح لك استئجار سيارة في القاهرة بضغطات قليلة.

• تصفح الأسطول بالأسعار وعدد المقاعد ونوع الوقود والتقييمات.
• اختر تواريخك واعرف عدد السيارات المتاحة من كل طراز.
• احجز أكثر من سيارة من نفس الطراز ورتّب الألوان حسب تفضيلك.
• حدد نقطتي الاستلام والتسليم على الخريطة.
• ادفع بالبطاقة أو المحفظة الإلكترونية أونلاين، أو عبر إنستاباي أو تحويل المحفظة، أو نقداً عند الاستلام.
• وقّع عقد الإيجار داخل التطبيق.
• تابع السائق، وسجّل العداد وحالة السيارة عند الاستلام والإرجاع.
• استلم إشعارات عند تأكيد الحجز أو تغيّر حالة الرحلة.
• اسأل المساعد الذكي عن السيارات والحجوزات وطرق الدفع.
• دعم كامل للعربية والإنجليزية، مع الدخول بالبصمة أو Face ID.

بياناتك محمية: راجع سياسة الخصوصية. يمكنك حذف حسابك في أي وقت من الملف الشخصي.

**الجديد (1.0.5)**

أزرار الاتصال والبريد الإلكتروني وواتساب تعمل الآن بشكل موثوق، ويفتح تطبيق إنستاباي مباشرة. إصلاح تسجيل الدخول لكلمات المرور التي تبدأ أو تنتهي بمسافة، رسائل أوضح عند فشل رفع الصور، أسعار محدّثة عند الحجز من المفضلة، وإصلاحات أخرى في الحجز.

## Notes for the reviewer (paste into "Comments to certification team")

The app is a car-rental demo for Cairo. Customers sign up in the app
(Sign Up on the login screen) or use this test account:

- Email: `REVIEWER_EMAIL` (create it first, see below)
- Password: `REVIEWER_PASSWORD`

To test a booking: Browse Cars → Rent → pick dates and the two map
locations → Continue to Payment → Sign Rental Agreement → Cash on Pickup.
Online card and wallet payments run in Paymob test mode; no real money
is taken. Location is used only while the map is open. Camera and photos
are used for ID, licence, receipt and odometer pictures.

Before submitting, create the reviewer account: open the app (or the web
demo), tap **Sign Up**, and use an email you control and a strong password;
then complete the profile once (phone, national ID and the two photos can be
sample images). Put that email and password above.

## Checklist

1. Create a free seller account at seller.samsungapps.com (individual).
2. Add New Application → Android → upload the APK.
3. Fill App Information with the texts above; add Arabic under languages.
4. Upload `icon_512.png` and the screenshots (English first, Arabic for the Arabic listing).
5. Answer the age-rating questionnaire (no violence, gambling or mature content).
6. Enter the privacy policy URL and the reviewer notes with the test account.
7. Countries: Egypt. Price: free. Submit for review (usually a few days).
