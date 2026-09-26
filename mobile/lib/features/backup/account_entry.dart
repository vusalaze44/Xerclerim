import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../transactions/local_ledger.dart';
import 'google_backup_auth.dart';

/// Keep guest data intact and offer a one-time copy into an empty account store.
Future<User?> signInWithGuestContinuity(BuildContext context, LocalLedger guest) async {
  final hasGuestData = await guest.hasAnyData();
  final snapshot = hasGuestData ? await guest.exportSnapshot() : null;
  final credential = await GoogleBackupAuth.signIn();
  final user = credential.user;
  if (user == null || snapshot == null || !context.mounted) return user;
  final account = LocalLedger(ownerUid: user.uid);
  try {
    if (await account.hasAnyData() || !context.mounted) return user;
    final copy = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('Qonaq qeydləri köçürülsün?'),
      content: const Text('Bu cihazdakı qeydlər hesabınızın boş lokal sahəsinə kopyalanacaq. Qonaq qeydləri saxlanılacaq. Buluda yedəkləmək üçün ayrıca “İndi yedəklə” seçin.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('İndi yox')),
        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Köçür')),
      ],
    ));
    if (copy == true) await account.importSnapshot(snapshot, replaceExisting: false);
  } finally { await account.close(); }
  return user;
}
