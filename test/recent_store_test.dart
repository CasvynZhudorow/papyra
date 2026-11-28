import 'package:flutter_test/flutter_test.dart';
import 'package:papyra/services/recent_store.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);

  group('RecentStore.merge', () {
    test('new path goes first', () {
      final merged = RecentStore.merge(const [], '/a.pdf', t0);
      expect(merged.single.path, '/a.pdf');
      expect(merged.single.openedAt, t0);
    });

    test('reopening moves path to front without duplicating', () {
      final all = [RecentFile('/a.pdf', t0), RecentFile('/b.pdf', t0)];
      final merged = RecentStore.merge(all, '/a.pdf', t0.add(hours: 1));
      expect(merged.map((r) => r.path), ['/a.pdf', '/b.pdf']);
      expect(merged.first.openedAt, t0.add(hours: 1));
    });

    test('json round trip', () {
      final r = RecentFile('/x/y.pdf', t0);
      expect(RecentFile.fromJson(r.toJson()).path, '/x/y.pdf');
      expect(RecentFile.fromJson(r.toJson()).openedAt, t0);
    });
  });
}