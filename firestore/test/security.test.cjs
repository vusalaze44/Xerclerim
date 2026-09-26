const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');

(async () => {
  const environment = await initializeTestEnvironment({
    projectId: 'demo-xerclerim',
    firestore: {rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8')},
  });
  try {
    const alice = environment.authenticatedContext('alice').firestore();
    const bob = environment.authenticatedContext('bob').firestore();
    const anonymous = environment.unauthenticatedContext().firestore();
    const ref = alice.doc('users/alice/backups/b1');
    const manifest = {schemaVersion: 1, chunkCount: 1, byteLength: 3,
      sha256: 'a'.repeat(64), recordCount: 1, createdAt: new Date()};
    await assertSucceeds(ref.set(manifest));
    await assertSucceeds(ref.get());
    await assertFails(bob.doc(ref.path).get());
    await assertFails(anonymous.doc(ref.path).get());
    await assertFails(bob.doc('users/alice/backups/b2').set(manifest));
    await assertFails(ref.update({recordCount: 2}));
    await assertFails(alice.doc('users/alice/backups/b2').set({schemaVersion: 1}));
    await assertSucceeds(alice.doc('users/alice/backups/b1/chunks/0000').set({index: 0, payload: 'abc'}));
    await assertFails(bob.doc('users/alice/backups/b1/chunks/0000').get());
    await assertFails(alice.doc('users/alice/backups/b1/chunks/0001').set({index: 1, payload: 'a'.repeat(160001)}));
    await environment.withSecurityRulesDisabled(async context => {
      await context.firestore().doc('debts/d1').set({lenderUid: 'alice', borrowerUid: 'bob'});
    });
    await assertSucceeds(bob.doc('debts/d1').get());
    await assertFails(anonymous.doc('debts/d1').get());
    await assertFails(bob.doc('debts/d1').update({outstandingQepik: 0}));
    console.log('Firestore owner isolation, immutable backup, and debt rules: OK');
  } finally { await environment.cleanup(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
