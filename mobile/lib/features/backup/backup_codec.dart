import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class EncodedBackup {
  const EncodedBackup(this.chunks, this.byteLength, this.digest);
  final List<String> chunks;
  final int byteLength;
  final String digest;
}

class BackupCodec {
  static const chunkSize = 160000;
  static const maxChunks = 200;

  static EncodedBackup encode(Map<String, dynamic> snapshot) {
    final bytes = utf8.encode(jsonEncode(snapshot));
    final encoded = base64Encode(bytes);
    final chunks = <String>[];
    for (var offset = 0; offset < encoded.length; offset += chunkSize) {
      chunks.add(encoded.substring(offset, min(offset + chunkSize, encoded.length)));
    }
    if (chunks.isEmpty || chunks.length > maxChunks) {
      throw const FormatException('Yedək üçün məlumat həcmi çox böyükdür.');
    }
    return EncodedBackup(chunks, bytes.length, sha256.convert(bytes).toString());
  }

  static Map<String, dynamic> decode(List<String> chunks, int byteLength, String digest) {
    if (chunks.isEmpty || chunks.length > maxChunks ||
        chunks.any((chunk) => chunk.length > chunkSize)) {
      throw const FormatException('Yedəyin hissələri düzgün deyil.');
    }
    final bytes = base64Decode(chunks.join());
    if (bytes.length != byteLength || sha256.convert(bytes).toString() != digest) {
      throw const FormatException('Yedəyin bütövlüyü yoxlanmadı.');
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) throw const FormatException('Yedək düzgün deyil.');
    return decoded;
  }
}
