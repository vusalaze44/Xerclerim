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

Xərclər ekranında aylıq kateqoriya bölgüsü, axtarış, kateqoriya filtri, limitlər və adi xərcləri düzəltmə/silmə var. Silinən qeydlər gələcək sinxronizasiya üçün lokal bazada işarələnir.

Plan ekranı qeydə alınmış bu aylıq pul axınına və istifadəçinin gələcək gəlir/xərc fərziyyələrinə əsasən nağd və hissəli alış ssenarilərini müqayisə edir. Hesab balansını oxumur, satınalma qərarı vermir və gələcək ayların ödəmə qabiliyyətini qiymətləndirmir.

Məqsədlər bölməsində hədəf, son tarix, yığılan məbləğ, geri götürmə və tarixçə cihazda saxlanır. Bu, real bank hesabı və ya pul köçürməsi deyil.

## Google hesabı ilə ehtiyat nüsxəsi

Google Sign-In + Firebase Auth hesabı ilə daxil olun, əsas ekrandakı bulud ikonundan **İndi yedəklə** seçin. Yedək Firestore-da həmin `uid` altında hissələrə bölünərək saxlanır. Bütün hissələr yazıldıqdan sonra manifest yaradılır və serverdən yenidən oxunaraq təsdiqlənir. Son yedəyi başqa cihazda **Bərpa et** ilə gətirmək mümkündür. Bərpa həmin hesabın cihazdakı məlumatlarını əvəz edir; təsdiq dialoqu göstərilir. Qonaq məlumatı hesaba yalnız ayrıca düymə ilə, hesabın lokal bazası boş olduqda kopyalanır. Google Drive icazəsi tələb edilmir.

Bu versiyada yedəkləmə **əl ilədir**; avtomatik fon sinxronizasiyası, lokal şifrələmə və App Check ilə mobil yedək qorunması buraxılışdan əvvəl əlavə edilməlidir. Firebase layihəsi qoşulmamış tətbiq lokal rejimdə açılır.

Quraşdırma: [docs/google-backup-setup.md](docs/google-backup-setup.md).
