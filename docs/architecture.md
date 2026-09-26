# Arxitektura

- Flutter: Android və iOS; bütün pul məbləğləri integer qəpik, tarixlər UTC olaraq saxlanılır, ekranda yerli vaxta çevrilir.
- Lokal baza: SQLite. Gəlir/xərc yazısı əvvəl cihazda yaradılır; `sync_state=pending` gələcək sinxronizasiya işçisi üçündür. Hazırkı buraxılışda sinxronizasiya işçisi yoxdur.
- Gələcək giriş: Firebase Auth; hər bulud sənədinin sahibi `uid` ilə bağlanır. Lokal bazadakı məlumatların hesablar arasında qarışmaması üçün hesab üzrə ayrılmış DB və çıxış zamanı təmizləmə siyasəti lazımdır.
- Bulud: Firestore yalnız istifadəçinin şəxsi məlumatlarına sahiblik qaydaları ilə; ikitərəfli borclar isə yalnız Cloud Functions transaksiya keçidləri vasitəsilə dəyişir.
- Konflikt: eyni əməliyyat üçün sabit UUID/idempotency açarı; özəl əməliyyatlarda versiya və server vaxtı. Borc/ödənişlərdə client son yazan qalib prinsipi tətbiq edilmir; imzalanmış hadisə tarixçəsi və server əməliyyatı əsasdır.
- Həssas məlumatlar: lokal bazanın şifrələnməsi, təhlükəsiz açar saxlanması və biometrik kilid Firebase inteqrasiyası ilə tətbiq edilməlidir. Bu skeletdə SQLite hələ şifrələnmir.
- Hesablama: kredit amortizasiyası, qalıq və proqnoz test edilən deterministik mühərrikdə hesablanacaq. AI yalnız hesablanmış nəticəni izah edəcək; ilkin versiyada fərdi investisiya və ya kredit qərarı verməyəcək.
- Push bildirişlər: FCM yalnız xatırlatma; məbləğ kimi həssas məlumat kilid ekranında göstərilməməlidir. Planlı ödənişlər idempotent server işi ilə yaradılacaq.

## Dost borcu vəziyyətləri

`sorğu -> qəbul/rədd -> aktiv -> qismən ödənib -> bağlanıb`; ödəniş təklifi ayrıca `gözləyir -> təsdiq/etiraz` vəziyyətindədir. Tərəflərdən heç biri qarşı tərəfin təsdiqini öz adından yaza bilməz. Hər hadisə dəyişdirilməyən audit qeydidir; mübahisə tətbiqin özündə pul köçürməsi kimi təqdim olunmur.

Cloud Functions dost borcunun yaradılması, qəbulu, ödəniş təklifi və təsdiqini Firestore transaksiyaları ilə edir. App Check məcburidir. İştirakçılar borc və hadisələri oxuya bilir, birbaşa yaza bilmirlər. Mobil Auth/FCM hələ qoşulmayıb; push xatırlatmalar ayrıca qurulacaq.
