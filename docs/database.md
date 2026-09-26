# Firestore məlumat modeli (hədəf)

| Yol | Əsas sahələr | Yazma qaydası |
| --- | --- | --- |
| `users/{uid}` | locale, currency, reminderPrefs | yalnız sahibi |
| `users/{uid}/transactions/{id}` | kind, amountQepik, categoryId, occurredAt, version | yalnız sahibi; idempotent |
| `users/{uid}/budgets/{id}` | categoryId, month, limitQepik | yalnız sahibi |
| `users/{uid}/loans/{id}` | principalQepik, annualRateBps, months, dueDay, outstandingQepik | yalnız sahibi; ödəniş hadisələri ayrıca |
| `users/{uid}/goals/{id}` | targetQepik, savedQepik, deadline | yalnız sahibi |
| `debts/{id}` | lenderUid, borrowerUid, amountQepik, dueAt, state, version | yalnız server funksiyası |
| `debts/{id}/events/{id}` | type, actorUid, amountQepik, createdAt, idempotencyKey | yalnız server funksiyası, append-only |
| `users/{uid}/notifications/{id}` | type, referenceId, readAt | server yaradır; sahibi oxuyur |
| `users/{uid}/insights/{id}` | calculatedFacts, explanation, generatedAt | server yaradır; sahibi oxuyur |

Şəxsi borc sorğusu göndərən və alan iki fərqli tərəfdir; sorğu yalnız alıcı tərəfindən qəbul edilir. Borc təsdiqlənməyənədək maliyyə balansına daxil edilmir. Qaytarılma təklifi alıcının təsdiqindən əvvəl qalığı azaltmır. Yazma zamanı `request.auth.uid`, iştirakçı rolu, `version`, məbləğ limiti və təkrar idempotency açarı serverdə yoxlanır. İstifadəçi axtarışı e-poçtu və telefon nömrəsini açıq indeksə çıxarmamalıdır.
