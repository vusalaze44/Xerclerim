import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

initializeApp();
const db = getFirestore();
const region = 'europe-west1';
const options = { region, enforceAppCheck: true };
const maxQepik = 100_000_000; // 1,000,000 AZN

type Input = Record<string, unknown>;
function object(value: unknown): Input {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new HttpsError('invalid-argument', 'Sorğu məlumatları düzgün deyil.');
  }
  return value as Input;
}
function uid(auth: { uid: string } | undefined): string {
  if (!auth) throw new HttpsError('unauthenticated', 'Hesabınıza daxil olun.');
  return auth.uid;
}
function string(value: unknown, field: string, limit = 120): string {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > limit) {
    throw new HttpsError('invalid-argument', `${field} düzgün deyil.`);
  }
  return value.trim();
}
function amount(value: unknown): number {
  if (!Number.isSafeInteger(value) || (value as number) < 1 || (value as number) > maxQepik) {
    throw new HttpsError('invalid-argument', 'Məbləği düzgün daxil edin.');
  }
  return value as number;
}
function requestId(value: unknown): string {
  const id = string(value, 'Əməliyyat kodu', 64);
  if (!/^[a-zA-Z0-9_-]{16,64}$/.test(id)) {
    throw new HttpsError('invalid-argument', 'Əməliyyat kodu düzgün deyil.');
  }
  return id;
}
function debtId(value: unknown): string {
  const id = string(value, 'Borc kodu', 160);
  if (!/^[a-zA-Z0-9_-]{16,160}$/.test(id)) {
    throw new HttpsError('invalid-argument', 'Borc kodu düzgün deyil.');
  }
  return id;
}
function dueDate(value: unknown): Timestamp {
  if (!Number.isSafeInteger(value)) throw new HttpsError('invalid-argument', 'Tarix düzgün deyil.');
  const now = Date.now();
  if ((value as number) < now || (value as number) > now + 5 * 366 * 86400000) {
    throw new HttpsError('invalid-argument', 'Qaytarılma tarixi 5 il ərzində olmalıdır.');
  }
  return Timestamp.fromMillis(value as number);
}
function participants(debt: FirebaseFirestore.DocumentData, actor: string): void {
  if (debt.lenderUid !== actor && debt.borrowerUid !== actor) {
    throw new HttpsError('permission-denied', 'Bu borca giriş yoxdur.');
  }
}

/** The lender proposes an IOU. Neither balance becomes active before borrower acceptance. */
export const createDebtRequest = onCall(options, async (call) => {
  const lenderUid = uid(call.auth);
  const data = object(call.data);
  const borrowerUid = string(data.borrowerUid, 'Qarşı tərəf', 128);
  if (borrowerUid === lenderUid || borrowerUid.includes('/')) {
    throw new HttpsError('invalid-argument', 'Qarşı tərəfi düzgün seçin.');
  }
  const principalQepik = amount(data.amountQepik);
  const dueAt = dueDate(data.dueAtMs);
  const note = data.note == null ? '' : string(data.note, 'Qeyd', 300);
  const id = `${lenderUid}_${requestId(data.requestId)}`;
  // Check existence before disclosing a request to the recipient.
  try { await getAuth().getUser(borrowerUid); }
  catch { throw new HttpsError('not-found', 'İstifadəçi tapılmadı.'); }
  const ref = db.doc(`debts/${id}`);
  const throttle = db.doc(`debt_request_limits/${lenderUid}`);
  await db.runTransaction(async (tx) => {
    const [existing, limit] = await Promise.all([tx.get(ref), tx.get(throttle)]);
    if (existing.exists) {
      if (existing.get('lenderUid') === lenderUid && existing.get('borrowerUid') === borrowerUid &&
          existing.get('principalQepik') === principalQepik) return;
      throw new HttpsError('already-exists', 'Əməliyyat kodu artıq istifadə olunub.');
    }
    if (limit.exists && Date.now() - (limit.get('lastAt') as Timestamp).toMillis() < 30000) {
      throw new HttpsError('resource-exhausted', 'Yeni sorğu göndərməzdən əvvəl gözləyin.');
    }
    tx.create(ref, { lenderUid, borrowerUid, principalQepik,
      outstandingQepik: 0, dueAt, note, state: 'requested', pendingPayment: null,
      createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(), version: 1 });
    tx.create(ref.collection('events').doc('created'), {
      type: 'requested', actorUid: lenderUid, amountQepik: principalQepik,
      createdAt: FieldValue.serverTimestamp() });
    tx.set(throttle, { lastAt: FieldValue.serverTimestamp() });
  });
  return { debtId: id };
});

export const respondDebtRequest = onCall(options, async (call) => {
  const actor = uid(call.auth);
  const data = object(call.data);
  const ref = db.doc(`debts/${debtId(data.debtId)}`);
  const accept = data.accept;
  if (typeof accept !== 'boolean') throw new HttpsError('invalid-argument', 'Qərarı seçin.');
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError('not-found', 'Borc sorğusu tapılmadı.');
    const debt = snap.data()!;
    if (actor !== debt.borrowerUid) throw new HttpsError('permission-denied', 'Sorğunu yalnız alan şəxs təsdiqləyə bilər.');
    if (debt.state !== 'requested') throw new HttpsError('failed-precondition', 'Bu sorğu artıq cavablandırılıb.');
    tx.update(ref, { state: accept ? 'active' : 'rejected',
      outstandingQepik: accept ? debt.principalQepik : 0,
      version: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp() });
    tx.create(ref.collection('events').doc('response'), { type: accept ? 'accepted' : 'rejected',
      actorUid: actor, createdAt: FieldValue.serverTimestamp() });
  });
  return { state: accept ? 'active' : 'rejected' };
});

export const proposeDebtPayment = onCall(options, async (call) => {
  const actor = uid(call.auth);
  const data = object(call.data);
  const ref = db.doc(`debts/${debtId(data.debtId)}`);
  const paidQepik = amount(data.amountQepik);
  const id = requestId(data.requestId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError('not-found', 'Borc tapılmadı.');
    const debt = snap.data()!;
    if (actor !== debt.borrowerUid) throw new HttpsError('permission-denied', 'Ödənişi borclu bildirə bilər.');
    if (debt.state !== 'active' || debt.pendingPayment != null || paidQepik > debt.outstandingQepik) {
      throw new HttpsError('failed-precondition', 'Ödəniş bu borca uyğun deyil.');
    }
    tx.update(ref, { pendingPayment: { id, amountQepik: paidQepik },
      version: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp() });
    tx.create(ref.collection('events').doc(`payment_${id}`), {
      type: 'payment_proposed', actorUid: actor, amountQepik: paidQepik,
      createdAt: FieldValue.serverTimestamp() });
  });
  return { paymentId: id };
});

export const respondDebtPayment = onCall(options, async (call) => {
  const actor = uid(call.auth);
  const data = object(call.data);
  const ref = db.doc(`debts/${debtId(data.debtId)}`);
  const id = requestId(data.paymentId);
  const accept = data.accept;
  if (typeof accept !== 'boolean') throw new HttpsError('invalid-argument', 'Qərarı seçin.');
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError('not-found', 'Borc tapılmadı.');
    const debt = snap.data()!;
    participants(debt, actor);
    if (actor !== debt.lenderUid) throw new HttpsError('permission-denied', 'Ödənişi yalnız borc verən təsdiqləyə bilər.');
    if (debt.state !== 'active' || debt.pendingPayment?.id !== id) {
      throw new HttpsError('failed-precondition', 'Bu ödəniş artıq cavablandırılıb.');
    }
    const paid = debt.pendingPayment.amountQepik as number;
    const remaining = debt.outstandingQepik - (accept ? paid : 0);
    if (remaining < 0) throw new HttpsError('failed-precondition', 'Məbləğ qalığı aşır.');
    tx.update(ref, { outstandingQepik: remaining, pendingPayment: null,
      state: remaining === 0 ? 'closed' : 'active',
      version: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp() });
    tx.create(ref.collection('events').doc(`response_${id}`), {
      type: accept ? 'payment_accepted' : 'payment_disputed', actorUid: actor,
      amountQepik: paid, createdAt: FieldValue.serverTimestamp() });
  });
  return { accepted: accept };
});
