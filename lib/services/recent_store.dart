import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A PDF the user opened recently.
class RecentFile {
  const RecentFile(this.path, this.openedAt);

  final String path;
  final DateTime openedAt;

  String get name => p.basename(path);

  Map<String, dynamic> toJson() =>
      {'path': path, 'at': openedAt.millisecondsSinceEpoch};

  factory RecentFile.fromJson(Map<String, dynamic> json) => RecentFile(
        json['path'] as String,
        DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
      );
}

/// Recent-files list, kept as a small JSON file in the app documents dir.
class RecentStore {
  static const limit = 10;

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'recent.json'));
  }

  /// Newest first, missing files dropped.
  static Future<List<RecentFile>> load() async {
    final f = await _file();
    if (!f.existsSync()) return const [];
    try {
      final raw = jsonDecode(f.readAsStringSync()) as List;
      return raw
          .map((e) => RecentFile.fromJson(e as Map<String, dynamic>))
          .where((r) => File(r.path).existsSync())
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> add(String path) async {
    final all = await load();
    await _save(merge(all, path, DateTime.now()));
  }

  static Future<void> remove(String path) async {
    final all = await load();
    await _save(all.where((r) => r.path != path).toList());
  }

  static Future<void> clear() async {
    final f = await _file();
    if (f.existsSync()) f.deleteSync();
  }

  static Future<void> _save(List<RecentFile> list) async {
    final f = await _file();
    f.writeAsStringSync(jsonEncode(list.take(limit).map((r) => r.toJson()).toList()));
  }

  /// Pure merge used by [add]: path first, older entries kept in order.
  static List<RecentFile> merge(
      List<RecentFile> all, String path, DateTime now) {
    return [
      RecentFile(path, now),
      for (final r in all)
        if (r.path != path) r,
    ];
  }
}