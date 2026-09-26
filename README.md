# Xərclərim

Şəxsi maliyyə, kredit və dost borclarını vahid öhdəlik mənzərəsində birləşdirən Flutter layihəsi.

## Hazırkı tətbiq

Giriş ekranı olmadan gəlir, xərc, büdcə, kredit, plan və yığım məqsədləri cihazda işləyir. Əsas ekran açıq fon, bənövşəyi aylıq xülasə, tarix seçimi, pastel funksiya kartları və pillə formasında alt naviqasiya ilə qurulub. Google hesabı yalnız bulud yedəyi və qarşılıqlı dost borcu sorğuları üçün tələb olunur.

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

Google Sign-In + Firebase Auth hesabı ilə daxil olun, əsas ekrandakı bulud ikonundan **İndi yedəklə** seçin. Yedək Firestore-da həmin `uid` altında hissələrə bölünərək saxlanır. Bütün hissələr yazıldıqdan sonra manifest yaradılır və serverdən yenidən oxunaraq təsdiqlənir. Son yedəyi başqa cihazda **Bərpa et** ilə gətirmək mümkündür. Bərpa həmin hesabın cihazdakı məlumatlarını əvəz edir; təsdiq dialoqu göstərilir. Giriş zamanı hesabın lokal bazası boşdursa qonaq qeydlərinin kopyalanması təklif edilir; imtina edildikdə qonaq qeydləri saxlanılır və sonradan ayrıca düymə ilə köçürülə bilər. Google Drive icazəsi tələb edilmir.

Bu versiyada yedəkləmə **əl ilədir**; avtomatik fon sinxronizasiyası, lokal şifrələmə və App Check ilə mobil yedək qorunması buraxılışdan əvvəl əlavə edilməlidir. Firebase layihəsi qoşulmamış tətbiq lokal rejimdə açılır.

Quraşdırma: [docs/google-backup-setup.md](docs/google-backup-setup.md).

## Dost borcları

Hər iki şəxs Google hesabı ilə daxil olur. Qarşı tərəf öz istifadəçi kodunu tətbiqdən kopyalayıb paylaşır; bu kodla sorğu göndərilir. Alan şəxs sorğunu qəbul və ya rədd edir. Qəbul edilmiş borc üzrə borclu ödəniş bildirir, borc verən təsdiqləyir və ya etiraz edir. Qarşılıqlı təsdiq olmadan borc qalığı dəyişmir. Dost borcu qeydləri Cloud Functions və Firestore üzərindədir; bağlantı, Firebase Auth və App Check quraşdırılması tələb olunur. Push bildirişləri bu mərhələdə yoxdur, siyahı **Yenilə** ilə serverdən oxunur.

Firebase layihəsində `europe-west1` funksiyalarını və Firestore qaydalarını yerləşdirin. Android üçün Play Integrity, Apple üçün App Attest provayderlərini Firebase konsolunda qeydiyyatdan keçirin; debug quruluşda göstərilən App Check debug tokenini həmin layihəyə əlavə edin. Mobil Firebase konfiqurasiyası, Google Sign-In SHA və bundle ID ayarları tamamlanmalıdır. Bunlar qoşulmamış lokal tətbiq girişsiz işləyir.
