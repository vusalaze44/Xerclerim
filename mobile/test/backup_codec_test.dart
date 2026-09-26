import 'package:flutter_test/flutter_test.dart';
import 'package:xerclerim/features/backup/backup_codec.dart';

void main() {
  test('Unicode və çox hissəli yedək eyni məlumatı qaytarır', () {
    final original = <String, dynamic>{'schemaVersion': 1,
      'tables': {'ledger': [{'note': List.filled(12000, 'Əməkhaqqı · yanacaq 🌿').join()}]}};
    final encoded = BackupCodec.encode(original);
    expect(encoded.chunks.length, greaterThan(1));
    expect(BackupCodec.decode(encoded.chunks, encoded.byteLength, encoded.digest), original);
    final damaged = [...encoded.chunks];
    damaged[0] = 'A${damaged[0].substring(1)}';
    expect(() => BackupCodec.decode(damaged, encoded.byteLength, encoded.digest),
      throwsFormatException);
  });
}
