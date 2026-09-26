# Xərclərim

Şəxsi maliyyə, kredit və dost borclarını vahid öhdəlik mənzərəsində birləşdirən Flutter layihəsi.

## Mövcud başlanğıc

`mobile/` daxilində AZN qəpik dəqiqliyi ilə işləyən gəlir/xərc qeydiyyatı, cihazda SQLite saxlanması və cari ayın xülasəsi var. Bu mərhələdə qeydiyyat, bulud sinxronizasiyası, kredit, dost borcu, bildiriş və AI ekranları hələ işlək deyil. `firestore/` qaydaları girişləri tam bağlayır; Firebase qoşulmadan öncə mülkiyyət və vəziyyət keçidləri serverdə qurulmalıdır.

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
