import 'package:flutter_test/flutter_test.dart';
import 'package:papyra/core/page_ranges.dart';

void main() {
  group('parsePageRanges', () {
    test('single page', () => expect(parsePageRanges('3', 10), [3]));
    test('list + range', () =>
        expect(parsePageRanges('1,3,5-8', 10), [1, 3, 5, 6, 7, 8]));
    test('reversed range normalised', () =>
        expect(parsePageRanges('5-3', 10), [3, 4, 5]));
    test('duplicates collapse', () => expect(parsePageRanges('2,2,2', 10), [2]));
    test('out of range throws', () =>
        expect(() => parsePageRanges('1-11', 10), throwsA(isA<PdfOpError>())));
    test('garbage throws', () =>
        expect(() => parsePageRanges('a,b', 10), throwsA(isA<PdfOpError>())));
    test('empty throws', () =>
        expect(() => parsePageRanges(' , ', 10), throwsA(isA<PdfOpError>())));
  });

  test('humanSize', () {
    expect(humanSize(512), '512 B');
    expect(humanSize(2048), '2.0 KB');
    expect(humanSize(5 * 1024 * 1024), '5.00 MB');
  });
}
