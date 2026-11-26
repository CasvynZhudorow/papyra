import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/page_ranges.dart';

export '../core/page_ranges.dart' show PdfOpError, parsePageRanges;

/// Result of a long-running PDF operation.
class OpResult {
  const OpResult(this.outputPath, {this.note, this.extraFiles = const []});

  final String outputPath;
  final String? note;
  final List<String> extraFiles;
}

Future<Directory> _outbox() async {
  final dir = await getApplicationDocumentsDirectory();
  final out = Directory(p.join(dir.path, 'Papyra'));
  if (!out.existsSync()) out.createSync(recursive: true);
  return out;
}

Future<String> _uniquePath(String name, String ext) async {
  final dir = await _outbox();
  final base =
      p.basenameWithoutExtension(name).replaceAll(RegExp(r'[^\w\-. ]'), '_');
  final stamp = DateTime.now().millisecondsSinceEpoch;
  return p.join(dir.path, '${base}_$stamp.$ext');
}

Future<PdfDocument> _open(String path, {String? password}) async {
  try {
    return await PdfDocument.openFile(
      path,
      passwordProvider:
          password == null ? null : createSimplePasswordProvider(password),
    );
  } on PdfPasswordException {
    throw const PdfOpError('Sandi salah atau PDF dilindungi sandi');
  } on PdfException catch (e) {
    throw PdfOpError('Gagal membuka PDF: $e');
  }
}

Future<void> _write(String path, PdfDocument doc) async {
  final bytes = await doc.encodePdf();
  await File(path).writeAsBytes(bytes);
}

/// Page count and file size for the "Info Dokumen" tool.
Future<OpResult> documentInfo(String path) async {
  final doc = await _open(path);
  final size = await File(path).length();
  final pages = doc.pages.length;
  await doc.dispose();
  return OpResult(path, note: '$pages halaman · ${humanSize(size)}');
}

/// Merge several PDFs into one.
Future<OpResult> mergePdfs(List<String> paths, {String? password}) async {
  if (paths.length < 2) throw const PdfOpError('Pilih minimal dua PDF');
  final docs = <PdfDocument>[];
  PdfDocument? out;
  try {
    final pages = <PdfPage>[];
    for (final path in paths) {
      final d = await _open(path, password: password);
      docs.add(d);
      pages.addAll(d.pages);
    }
    out = await PdfDocument.createNew(sourceName: 'merged.pdf');
    out.pages = pages;
    final target = await _uniquePath('gabungan', 'pdf');
    await _write(target, out);
    return OpResult(target,
        note: '${pages.length} halaman dari ${paths.length} PDF');
  } finally {
    for (final d in docs) {
      await d.dispose();
    }
    await out?.dispose();
  }
}

/// Extract the given pages into a new document.
Future<OpResult> extractPages(
  String path,
  String ranges, {
  String? password,
}) async {
  final doc = await _open(path, password: password);
  PdfDocument? out;
  try {
    final wanted = parsePageRanges(ranges, doc.pages.length);
    out = await PdfDocument.createNew(sourceName: 'extract.pdf');
    out.pages = [for (final n in wanted) doc.pages[n - 1]];
    final target = await _uniquePath('ekstrak', 'pdf');
    await _write(target, out);
    return OpResult(target, note: '${wanted.length} halaman diambil');
  } finally {
    await doc.dispose();
    await out?.dispose();
  }
}

/// Rotate pages clockwise by 90/180/270 degrees.
Future<OpResult> rotatePages(
  String path,
  String ranges,
  int degrees, {
  String? password,
}) async {
  final doc = await _open(path, password: password);
  PdfDocument? out;
  try {
    final wanted = parsePageRanges(ranges, doc.pages.length).toSet();
    final delta = switch ((degrees % 360 + 360) % 360) {
      90 => PdfPageRotation.clockwise90,
      180 => PdfPageRotation.clockwise180,
      270 => PdfPageRotation.clockwise270,
      _ => PdfPageRotation.none,
    };
    out = await PdfDocument.createNew(sourceName: 'rotate.pdf');
    out.pages = [
      for (var i = 1; i <= doc.pages.length; i++)
        wanted.contains(i)
            ? doc.pages[i - 1].rotatedBy(delta)
            : doc.pages[i - 1],
    ];
    final target = await _uniquePath('putar', 'pdf');
    await _write(target, out);
    return OpResult(target,
        note: '$degrees° diterapkan ke ${wanted.length} halaman');
  } finally {
    await doc.dispose();
    await out?.dispose();
  }
}

/// Rotate some pages and delete others in one pass.
Future<OpResult> organizePages(
  String path, {
  required String rotate,
  String? delete,
  String? password,
}) async {
  final doc = await _open(path, password: password);
  PdfDocument? out;
  try {
    final total = doc.pages.length;
    final toRotate = parsePageRanges(rotate, total).toSet();
    final toDelete = (delete == null || delete.trim().isEmpty)
        ? <int>{}
        : parsePageRanges(delete, total).toSet();
    final pages = <PdfPage>[
      for (var i = 1; i <= total; i++)
        if (!toDelete.contains(i))
          (toRotate.contains(i)
              ? doc.pages[i - 1].rotatedCW90()
              : doc.pages[i - 1]),
    ];
    if (pages.isEmpty) throw const PdfOpError('Semua halaman terhapus');
    out = await PdfDocument.createNew(sourceName: 'organize.pdf');
    out.pages = pages;
    final target = await _uniquePath('atur', 'pdf');
    await _write(target, out);
    return OpResult(
      target,
      note: '${pages.length} halaman · ${toRotate.length} diputar · '
          '${toDelete.length} dihapus',
    );
  } finally {
    await doc.dispose();
    await out?.dispose();
  }
}

/// Render pages to images (PDF -> PNG/JPG).
Future<OpResult> pdfToImages(
  String path, {
  int dpi = 110,
  String format = 'png',
  String? password,
  void Function(int done, int total)? onProgress,
}) async {
  final doc = await _open(path, password: password);
  final dir = await _outbox();
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final base =
      p.basenameWithoutExtension(path).replaceAll(RegExp(r'[^\w\-. ]'), '_');
  final files = <String>[];
  try {
    final total = doc.pages.length;
    for (var i = 1; i <= total; i++) {
      final page = doc.pages[i - 1];
      final scale = dpi / 72.0;
      final image = await page.render(
        fullWidth: page.width * scale,
        fullHeight: page.height * scale,
      );
      if (image == null) continue;
      final data = format == 'jpg'
          ? img.encodeJpg(image.createImageNF(), quality: 88)
          : img.encodePng(image.createImageNF());
      image.dispose();
      final file = p.join(dir.path, '${base}_${stamp}_p$i.$format');
      await File(file).writeAsBytes(data);
      files.add(file);
      onProgress?.call(i, total);
    }
    if (files.isEmpty) {
      throw const PdfOpError('Tidak ada halaman yang bisa dirender');
    }
    return OpResult(files.first,
        extraFiles: files, note: '${files.length} gambar dibuat');
  } finally {
    await doc.dispose();
  }
}

/// Rebuild a PDF from rendered pages — shared by compress and watermark.
Future<String> _rebuildFromImages(
  String path,
  String outName, {
  required double scale,
  required int quality,
  String? password,
  String? watermark,
  void Function(int done, int total)? onProgress,
}) async {
  final doc = await _open(path, password: password);
  final out = pw.Document();
  try {
    final total = doc.pages.length;
    for (var i = 1; i <= total; i++) {
      final page = doc.pages[i - 1];
      final image = await page.render(
        fullWidth: page.width * scale,
        fullHeight: page.height * scale,
      );
      if (image == null) continue;
      final bytes = img.encodeJpg(image.createImageNF(), quality: quality);
      image.dispose();
      final pwImage = pw.MemoryImage(bytes);
      out.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(page.width, page.height, marginAll: 0),
          build: (context) {
            final content = pw.Image(pwImage, fit: pw.BoxFit.fill);
            if (watermark == null || watermark.isEmpty) return content;
            return pw.Stack(children: [
              content,
              pw.Positioned.fill(
                child: pw.Center(
                  child: pw.Transform.rotate(
                    angle: -0.6,
                    child: pw.Text(
                      watermark,
                      style: pw.TextStyle(
                        fontSize: 34,
                        color: PdfColor.fromInt(0x554F46E5),
                      ),
                    ),
                  ),
                ),
              ),
            ]);
          },
        ),
      );
      onProgress?.call(i, total);
    }
    if (out.pages.isEmpty) throw const PdfOpError('Tidak ada halaman diproses');
    final target = await _uniquePath(outName, 'pdf');
    await File(target).writeAsBytes(await out.save());
    return target;
  } finally {
    await doc.dispose();
  }
}

/// Downscale + re-encode pages to shrink file size.
Future<OpResult> compressPdf(
  String path, {
  int dpi = 96,
  int quality = 62,
  String? password,
  void Function(int done, int total)? onProgress,
}) async {
  final before = await File(path).length();
  final target = await _rebuildFromImages(
    path,
    'kompres',
    scale: dpi / 72.0,
    quality: quality,
    password: password,
    onProgress: onProgress,
  );
  final after = await File(target).length();
  final saved = before > 0 ? (100 - after * 100 ~/ before) : 0;
  return OpResult(
    target,
    note: '${humanSize(before)} → ${humanSize(after)} '
        '(${saved > 0 ? 'hemat $saved%' : 'tidak lebih kecil'})',
  );
}

/// Stamp a translucent text watermark on every page.
Future<OpResult> watermarkPdf(
  String path,
  String text, {
  int dpi = 110,
  String? password,
  void Function(int done, int total)? onProgress,
}) async {
  if (text.trim().isEmpty) throw const PdfOpError('Teks watermark masih kosong');
  final target = await _rebuildFromImages(
    path,
    'watermark',
    scale: dpi / 72.0,
    quality: 80,
    password: password,
    watermark: text.trim(),
    onProgress: onProgress,
  );
  return OpResult(target, note: 'Watermark "${text.trim()}" diterapkan');
}

/// Remove password protection by re-saving without security.
Future<OpResult> decryptPdf(String path, String password) async {
  final doc = await _open(path, password: password);
  PdfDocument? out;
  try {
    out = await PdfDocument.createNew(sourceName: 'unlocked.pdf');
    out.pages = doc.pages;
    final target = await _uniquePath('tanpa_sandi', 'pdf');
    final bytes = await out.encodePdf(removeSecurity: true);
    await File(target).writeAsBytes(bytes);
    return OpResult(target, note: 'Sandi dilepas, ${doc.pages.length} halaman');
  } finally {
    await doc.dispose();
    await out?.dispose();
  }
}

/// Build a PDF out of images.
Future<OpResult> imagesToPdf(List<String> paths) async {
  if (paths.isEmpty) throw const PdfOpError('Pilih minimal satu gambar');
  final out = pw.Document();
  for (final path in paths) {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) continue;
    final pwImage = pw.MemoryImage(bytes);
    final ratio = decoded.width / decoded.height;
    out.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          PdfPageFormat.a4.width,
          PdfPageFormat.a4.width / ratio,
          marginAll: 0,
        ),
        build: (context) => pw.Image(pwImage, fit: pw.BoxFit.fill),
      ),
    );
  }
  if (out.pages.isEmpty) throw const PdfOpError('Tidak ada gambar yang terbaca');
  final target = await _uniquePath('dari_gambar', 'pdf');
  await File(target).writeAsBytes(await out.save());
  return OpResult(target, note: '${paths.length} gambar jadi PDF');
}

/// Best-effort text dump of a PDF, page by page.
Future<String> extractText(String path, {String? password}) async {
  final doc = await _open(path, password: password);
  final buffer = StringBuffer();
  try {
    for (final page in doc.pages) {
      final text = await page.loadText();
      buffer.writeln(text.fullText);
      buffer.writeln();
    }
  } finally {
    await doc.dispose();
  }
  return buffer.toString();
}