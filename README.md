# Xərclərim

Şəxsi maliyyə, kredit və dost borclarını vahid öhdəlik mənzərəsində birləşdirən Flutter layihəsi.

## Mövcud başlanğıc

`mobile/` daxilində AZN qəpik dəqiqliyi ilə işləyən gəlir/xərc qeydiyyatı, cihazda SQLite saxlanması və cari ayın xülasəsi və kredit üçün təxmini amortizasiya cədvəli var. Kredit cədvəli bankın faktiki borc qalığını və əlavə haqlarını əks etdirmir. Bu mərhələdə qeydiyyat, bulud sinxronizasiyası, dost borcunun mobil axını, bulud bağlantısı, bildiriş və AI ekranları hələ işlək deyil. `firestore/` qaydaları girişləri tam bağlayır; Firebase qoşulmadan öncə mülkiyyət və vəziyyət keçidləri serverdə qurulmalıdır.

## İşə salma

Flutter SDK quraşdırıldıqdan sonra:

```bash
cd mobile
flutter create --platforms=android,ios --project-name xerclerim .
flutter pub get
flutter analyze
flutter test
flutter run
```

`flutter create` platforma qovluqlarını ilk dəfə yaradır. Android/iOS quruluşunu, Firebase layihəsini və signing konfiqurasiyasını layihəyə uyğun tamamlayın. Firebase açarları depoya yüklənməməlidir.

Ətraflı qərarlar: [arxitektura](docs/architecture.md), [məlumat modeli](docs/database.md), [mərhələlər](docs/roadmap.md).

Kreditin faktiki ödənişi ayrıca qeydə alınır və eyni anda aylıq xərcə daxil edilir. Bu məbləğ bankın hesabladığı faktiki qalıq kimi göstərilmir. Dost borcu üçün qarşılıqlı təsdiqlənən Cloud Functions hazırlanıb; Firebase layihəsi və mobil giriş qoşulmayınca istifadə edilmir.
