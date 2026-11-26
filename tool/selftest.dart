/// Local self-check for the pure-Dart helpers: `dart run tool/selftest.dart`.
/// Exits non-zero on the first failed expectation.
library;

import 'dart:io';

import 'package:papyra/core/page_ranges.dart';

int _checks = 0;

bool listEq(List a, List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void eq(Object? actual, Object? expected, String label) {
  _checks++;
  final ok = (actual is List && expected is List)
      ? listEq(actual, expected)
      : actual == expected;
  if (!ok) {
    stderr.writeln('FAIL $label: expected $expected, got $actual');
    exit(1);
  }
}

void throws(String label, void Function() body) {
  _checks++;
  try {
    body();
  } on PdfOpError {
    return;
  }
  stderr.writeln('FAIL $label: expected PdfOpError');
  exit(1);
}

void main() {
  eq(parsePageRanges('3', 10), [3], 'single page');
  eq(parsePageRanges('1,3,5-8', 10), [1, 3, 5, 6, 7, 8], 'list + range');
  eq(parsePageRanges('5-3', 10), [3, 4, 5], 'reversed range');
  eq(parsePageRanges('2,2,2', 10), [2], 'duplicates collapse');
  eq(parsePageRanges(' 1 , 2 ', 10), [1, 2], 'whitespace tolerated');
  throws('out of range', () => parsePageRanges('1-11', 10));
  throws('zero page', () => parsePageRanges('0', 10));
  throws('garbage', () => parsePageRanges('a,b', 10));
  throws('empty', () => parsePageRanges(' , ', 10));

  eq(humanSize(512), '512 B', 'bytes');
  eq(humanSize(2048), '2.0 KB', 'kilobytes');
  eq(humanSize(5 * 1024 * 1024), '5.00 MB', 'megabytes');

  stdout.writeln('ok - $_checks checks passed');
}