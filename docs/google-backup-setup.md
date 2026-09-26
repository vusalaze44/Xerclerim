# Google yedəyini qoşma

1. Öz Firebase layihənizdə Android və iOS tətbiqlərini qeyd edin. `mobile/` qovluğunda `flutter create --platforms=android,ios --project-name xerclerim .` çalışdırın; tətbiq ID-lərini yekunlaşdırın.
2. Firebase Authentication içində **Google** provider-ini aktivləşdirin. Android debug və release SHA-1/SHA-256 sertifikat izlərini Firebase-ə əlavə edin. iOS URL scheme/GoogleService-Info.plist sazlamasını FlutterFire addımları ilə edin.
3. Firebase CLI və FlutterFire CLI ilə `flutterfire configure` çalışdırın. Native `google-services.json` və `GoogleService-Info.plist` faylları öz cihazlarınızda konfiqurasiya olunmalıdır. `Firebase.initializeApp()` hazırda native default app konfiqurasiyasını açır; generated options faylına əsaslanan variant seçiləcəksə `main.dart` uyğunlaşdırılmalıdır.
4. Firestore yaradın, `firebase deploy --only firestore:rules,firestore:indexes` ilə bu depodakı qaydaları tətbiq edin. **Qaydaları tətbiq etmədən yedəkləməni istifadəçilərə açmayın.** `functions/` hissəsi dost borcu üçün ayrıca deploy edilməlidir.
5. `cd mobile && flutter pub get && flutter analyze && flutter test && flutter run` yoxlayın. İki ayrı Google hesabı ilə izolyasiyanı, eyni hesabla iki cihazda yedək/bərpanı, internet kəsilməsində uğursuz yedək mesajını və qonaq məlumatlarının köçürülməsini test edin.

Məlumat Firestore-da saxlanır, istifadəçinin şəxsi Google Drive qovluğunda deyil. Yedəklər Firebase layihəsinin adminlərinə görünə bilər; end-to-end şifrələmə yoxdur. Silinən lokal qeydlər də bərpa formatında saxlanır ki, sonrakı sinxronizasiya mərhələsində dəyişiklik tarixçəsi itməsin. Köhnə yedəklərin silinməsi, hesabın silinməsi, şifrəli lokal baza və məlumatların ixracı istehsal buraxılışından əvvəl tamamlanmalıdır.

Qayda yoxlaması: `npm install --prefix firestore/test` və `npm --prefix firestore/test test`. Bu demo Firebase emulatorunda iki hesabın ayrılmasını, yedəyin dəyişdirilməməsini və borc yazma qadağasını yoxlayır.
