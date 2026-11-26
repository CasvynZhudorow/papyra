/// Pure-Dart helpers (no Flutter imports) so they can be unit-tested and
/// reused by the CLI self-check.
library;

/// Thrown for user-facing failures (bad page range, empty selection, ...).
class PdfOpError implements Exception {
  const PdfOpError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Parse "1,3,5-8" into a sorted, de-duplicated 1-based page list.
List<int> parsePageRanges(String input, int pageCount) {
  final out = <int>{};
  for (final part in input.split(',')) {
    final t = part.trim();
    if (t.isEmpty) continue;
    final m = RegExp(r'^(\d+)(?:\s*-\s*(\d+))?$').firstMatch(t);
    if (m == null) throw PdfOpError('Format halaman tidak valid: "$t"');
    final a = int.parse(m.group(1)!);
    final b = m.group(2) == null ? a : int.parse(m.group(2)!);
    final lo = a <= b ? a : b;
    final hi = a <= b ? b : a;
    if (lo < 1 || hi > pageCount) {
      throw PdfOpError('Halaman $lo-$hi di luar rentang 1-$pageCount');
    }
    for (var i = lo; i <= hi; i++) {
      out.add(i);
    }
  }
  if (out.isEmpty) throw const PdfOpError('Belum ada halaman yang dipilih');
  return out.toList()..sort();
}

/// 512 -> "512 B", 2048 -> "2.0 KB", 5 MiB -> "5.00 MB".
String humanSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}