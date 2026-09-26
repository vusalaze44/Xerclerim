/// All amounts are stored as integer qəpik to avoid floating point drift.
class Money {
  static int parseAzN(String input) {
    final normalized = input.trim().replaceAll(',', '.');
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(normalized);
    if (match == null) throw const FormatException('Məbləği düzgün daxil edin.');
    return int.parse(match[1]!) * 100 +
        int.parse((match[2] ?? '').padRight(2, '0'));
  }

  static String format(int qepik) {
    final sign = qepik < 0 ? '-' : '';
    final absolute = qepik.abs();
    return '$sign${absolute ~/ 100}.${(absolute % 100).toString().padLeft(2, '0')} ₼';
  }
}
