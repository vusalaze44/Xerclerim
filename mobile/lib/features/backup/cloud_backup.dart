import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'backup_codec.dart';

class BackupInfo {
  const BackupInfo(this.id, this.createdAt, this.recordCount);
  final String id;
  final DateTime createdAt;
  final int recordCount;
}

class CloudBackup {
  CloudBackup(this.firestore);
  final FirebaseFirestore firestore;
  CollectionReference<Map<String, dynamic>> _backups(String uid) =>
      firestore.collection('users').doc(uid).collection('backups');

  Future<BackupInfo> save(String uid, Map<String, dynamic> snapshot) async {
    final encoded = BackupCodec.encode(snapshot);
    final chunks = encoded.chunks;
    final random = Random.secure();
    final id = '${DateTime.now().microsecondsSinceEpoch}_${random.nextInt(0x7fffffff).toRadixString(16)}';
    final ref = _backups(uid).doc(id);
    for (var i = 0; i < chunks.length; i++) {
      await ref.collection('chunks').doc(i.toString().padLeft(4, '0')).set({
        'index': i, 'payload': chunks[i],
      }).timeout(const Duration(seconds: 30));
    }
    final tables = snapshot['tables'] as Map<String, dynamic>;
    final count = tables.values.fold<int>(0, (total, rows) => total + (rows as List).length);
    await ref.set({
      'schemaVersion': 1, 'chunkCount': chunks.length,
      'byteLength': encoded.byteLength, 'sha256': encoded.digest,
      'recordCount': count, 'createdAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 30));
    // Cached or queued writes are insufficient evidence of a completed backup.
    final verified = await ref.get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 30));
    if (!verified.exists || verified.data()?['sha256'] != encoded.digest) {
      throw const StateError('Yedək serverdə təsdiqlənmədi.');
    }
    final timestamp = verified.data()?['createdAt'] as Timestamp;
    return BackupInfo(id, timestamp.toDate(), count);
  }

  Future<List<BackupInfo>> list(String uid) async {
    final query = await _backups(uid).orderBy('createdAt', descending: true).limit(10)
        .get(const GetOptions(source: Source.server));
    return query.docs.map((doc) {
      final data = doc.data();
      return BackupInfo(doc.id, (data['createdAt'] as Timestamp).toDate(),
        data['recordCount'] as int);
    }).toList();
  }

  Future<Map<String, dynamic>> fetch(String uid, String backupId) async {
    final ref = _backups(uid).doc(backupId);
    final manifest = await ref.get(const GetOptions(source: Source.server));
    final data = manifest.data();
    if (data == null || data['schemaVersion'] != 1 ||
        data['chunkCount'] is! int || data['chunkCount'] < 1 ||
        data['chunkCount'] > BackupCodec.maxChunks) {
      throw const FormatException('Yedək tapılmadı və ya formatı düzgün deyil.');
    }
    final chunks = <String>[];
    for (var i = 0; i < data['chunkCount'] as int; i++) {
      final chunk = await ref.collection('chunks').doc(i.toString().padLeft(4, '0'))
          .get(const GetOptions(source: Source.server));
      if (!chunk.exists || chunk.data()?['index'] != i || chunk.data()?['payload'] is! String) {
        throw const FormatException('Yedəyin bir hissəsi çatışmır.');
      }
      chunks.add(chunk.data()!['payload'] as String);
    }
    return BackupCodec.decode(chunks, data['byteLength'] as int, data['sha256'] as String);
  }
}
