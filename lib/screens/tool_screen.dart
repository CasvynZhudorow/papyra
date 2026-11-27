import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../models/tool_def.dart';
import '../services/pdf_service.dart';
import 'viewer_screen.dart';

class ToolScreen extends StatefulWidget {
  const ToolScreen({super.key, required this.tool});

  final ToolDef tool;

  @override
  State<ToolScreen> createState() => _ToolScreenState();
}

class _ToolScreenState extends State<ToolScreen> {
  List<String> _inputs = [];
  bool _busy = false;
  String _progress = '';
  OpResult? _result;
  String? _error;

  // per-tool options
  final _rangeCtrl = TextEditingController(text: '1');
  final _deleteCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _watermarkCtrl = TextEditingController(text: 'CONFIDENTIAL');
  final int _degrees = 90;
  int _dpi = 110;
  int _quality = 62;
  String _imgFormat = 'png';

  // annotate tool state
  final List<AnnotationItem> _annotations = [];
  final _annotateTextCtrl = TextEditingController();
  double _annotateX = 100;
  double _annotateY = 100;
  double _annotateFontSize = 18;
  int _annotateColor = 0xFF000000;
  Uint8List? _annotateImageBytes;

  // redact tool state
  final List<RedactionArea> _redactions = [];
  double _redactX = 100;
  double _redactY = 100;
  double _redactWidth = 200;
  double _redactHeight = 50;

  ToolDef get tool => widget.tool;

  @override
  void dispose() {
    _rangeCtrl.dispose();
    _deleteCtrl.dispose();
    _passwordCtrl.dispose();
    _watermarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final isImage = tool.id == 'img2pdf';
    final isOpen = tool.id == 'open';
    final res = await FilePickerPlatform.instance.pickFiles(
      type: isImage ? FileType.image : FileType.custom,
      allowedExtensions: isImage || isOpen ? null : ['pdf'],
    );
    if (res == null) return;
    setState(() {
      _inputs = res.map((f) => f.path).whereType<String>().toList();
      _result = null;
      _error = null;
    });
  }

  Future<void> _run() async {
    if (_inputs.isEmpty) {
      setState(() => _error = 'Pilih berkas dulu');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _progress = 'Memproses…';
    });
    void onProgress(int done, int total) {
      if (!mounted) return;
      setState(() => _progress = 'Memproses $done/$total');
    }
    try {
      final op = await _dispatch(onProgress);
      if (!mounted) return;
      setState(() {
        _result = op;
        _progress = '';
      });
    } on PdfOpError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<OpResult> _dispatch(void Function(int, int)? onProgress) {
    final password = _passwordCtrl.text.isEmpty ? null : _passwordCtrl.text;
    switch (tool.id) {
      case 'open':
        return Future.value(OpResult(_inputs.first));
      case 'merge':
        return mergePdfs(_inputs, password: password);
      case 'extract':
        return extractPages(_inputs.first, _rangeCtrl.text, password: password);
      case 'rotate':
        return rotatePages(_inputs.first, _rangeCtrl.text, _degrees,
            password: password);
      case 'organize':
        return organizePages(
          _inputs.first,
          rotate: _rangeCtrl.text,
          delete: _deleteCtrl.text,
          password: password,
        );
      case 'compress':
        return compressPdf(_inputs.first,
            dpi: _dpi, quality: _quality, password: password, onProgress: onProgress);
      case 'pdf2img':
        return pdfToImages(_inputs.first,
            dpi: _dpi, format: _imgFormat, password: password, onProgress: onProgress);
      case 'img2pdf':
        return imagesToPdf(_inputs);
      case 'watermark':
        return watermarkPdf(_inputs.first, _watermarkCtrl.text,
            dpi: _dpi, password: password, onProgress: onProgress);
      case 'annotate':
        return annotatePdf(_inputs.first,
            annotations: _annotations, dpi: _dpi, quality: _quality, password: password, onProgress: onProgress);
      case 'redact':
        return redactPdf(_inputs.first,
            areas: _redactions, dpi: _dpi, quality: _quality, password: password, onProgress: onProgress);
      case 'decrypt':
        return decryptPdf(_inputs.first, _passwordCtrl.text);
      case 'metadata':
        return documentInfo(_inputs.first);
      default:
        throw const PdfOpError('Alat belum tersedia');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tool.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(tool.icon, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(tool.subtitle,
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_inputs.isEmpty)
            _dropZone(context)
          else
            _fileList(context),
          const SizedBox(height: 16),
          ..._options(context),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _banner(_error!, scheme.error, Icons.error_outline),
          ],
          if (_result != null) ...[
            const SizedBox(height: 12),
            _resultCard(context),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _run,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(_busy ? _progress : 'Jalankan'),
          ),
          if (_inputs.isNotEmpty)
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _inputs = [];
                        _result = null;
                        _error = null;
                      }),
              icon: const Icon(Icons.folder_open),
              label: const Text('Ganti berkas'),
            ),
        ],
      ),
    );
  }

  Widget _dropZone(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOpen = tool.id == 'open';
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _pick,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: scheme.primary.withValues(alpha: 0.35), width: 1.4),
          color: scheme.primary.withValues(alpha: 0.04),
        ),
        child: Column(
          children: [
            Icon(Icons.upload_file, size: 40, color: scheme.primary),
            const SizedBox(height: 10),
            Text(
              tool.id == 'img2pdf'
                  ? 'Pilih gambar'
                  : tool.multiInput
                      ? 'Pilih beberapa PDF'
                      : isOpen
                          ? 'Pilih PDF untuk dibuka'
                          : 'Pilih satu PDF',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text('Ketuk untuk membuka penelusur berkas',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _fileList(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < _inputs.length; i++)
            ListTile(
              leading: Icon(
                _inputs[i].toLowerCase().endsWith('.pdf')
                    ? Icons.picture_as_pdf_outlined
                    : Icons.image_outlined,
                color: scheme.primary,
              ),
              title: Text(
                _inputs[i].split(RegExp(r'[/\\]')).last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(_sizeLabel(_inputs[i])),
              trailing: IconButton(
                tooltip: 'Hapus dari daftar',
                icon: const Icon(Icons.close),
                onPressed: _busy
                    ? null
                    : () => setState(() => _inputs.removeAt(i)),
              ),
            ),
        ],
      ),
    );
  }

  String _sizeLabel(String path) {
    final f = File(path);
    if (!f.existsSync()) return '';
    final kb = f.lengthSync() / 1024;
    return kb < 1024 ? '${kb.toStringAsFixed(0)} KB' : '${(kb / 1024).toStringAsFixed(2)} MB';
  }

  List<Widget> _options(BuildContext context) {
    final range = TextField(
      controller: _rangeCtrl,
      decoration: const InputDecoration(
        labelText: 'Halaman',
        hintText: 'contoh: 1,3,5-8',
        prefixIcon: Icon(Icons.numbers),
      ),
    );
    final password = TextField(
      controller: _passwordCtrl,
      obscureText: tool.id != 'decrypt',
      decoration: InputDecoration(
        labelText: tool.id == 'decrypt' ? 'Sandi PDF' : 'Sandi (opsional)',
        prefixIcon: const Icon(Icons.password),
      ),
    );

    switch (tool.id) {
      case 'open':
        return [const Text('Pilih PDF lalu tekan Jalankan untuk membuka di penampil.')];
      case 'extract':
      case 'rotate':
        return [range, password];
      case 'organize':
        return [
          range,
          TextField(
            controller: _deleteCtrl,
            decoration: const InputDecoration(
              labelText: 'Hapus halaman (opsional)',
              hintText: 'contoh: 2,7',
              prefixIcon: Icon(Icons.delete_outline),
            ),
          ),
          Text('Halaman di "Halaman" diputar 90° searah jarum jam.',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          password,
        ];
      case 'compress':
        return [
          _slider('Resolusi', '$_dpi dpi', 72, 200, _dpi,
              (v) => setState(() => _dpi = v.round())),
          _slider('Kualitas JPEG', '$_quality%', 30, 95, _quality,
              (v) => setState(() => _quality = v.round())),
          password,
        ];
      case 'pdf2img':
        return [
          _slider('Resolusi', '$_dpi dpi', 72, 220, _dpi,
              (v) => setState(() => _dpi = v.round())),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'png', label: Text('PNG')),
              ButtonSegment(value: 'jpg', label: Text('JPG')),
            ],
            selected: {_imgFormat},
            onSelectionChanged: (s) => setState(() => _imgFormat = s.first),
          ),
          password,
        ];
      case 'watermark':
        return [
          TextField(
            controller: _watermarkCtrl,
            decoration: const InputDecoration(
              labelText: 'Teks watermark',
              prefixIcon: Icon(Icons.branding_watermark),
            ),
          ),
          _slider('Resolusi', '$_dpi dpi', 72, 200, _dpi,
              (v) => setState(() => _dpi = v.round())),
          password,
        ];
      case 'annotate':
        return _annotateOptions(context, password);
      case 'redact':
        return _redactOptions(context, password);
      case 'decrypt':
        return [password];
      case 'metadata':
        return [password];
      default:
        return [password];
    }
  }

  Widget _slider(String label, String value, num min, num max, num now,
      ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        Slider(
            value: now.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            onChanged: onChanged),
      ],
    );
  }

  List<Widget> _annotateOptions(BuildContext context, String? password) {
    final scheme = Theme.of(context).colorScheme;
    return [
      SegmentedButton<AnnotationType>(
        segments: const [
          ButtonSegment(
              value: AnnotationType.text,
              label: Text('Teks'),
              icon: Icon(Icons.text_fields)),
          ButtonSegment(
              value: AnnotationType.image,
              label: Text('Gambar'),
              icon: Icon(Icons.image)),
        ],
        selected: {AnnotationType.text},
        onSelectionChanged: (s) {},
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _annotateTextCtrl,
        decoration: const InputDecoration(
          labelText: 'Teks',
          prefixIcon: Icon(Icons.text_fields),
        ),
      ),
      _slider('Ukuran font', '$_annotateFontSize', 8, 72, _annotateFontSize,
          (v) => setState(() => _annotateFontSize = v)),
      _slider('Posisi X', '${_annotateX.toInt()}', 0, 800, _annotateX,
          (v) => setState(() => _annotateX = v)),
      _slider('Posisi Y', '${_annotateY.toInt()}', 0, 1100, _annotateY,
          (v) => setState(() => _annotateY = v)),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final res = await FilePickerPlatform.instance.pickFiles(
                  type: FileType.image,
                );
                if (res != null && res.isNotEmpty && res.single.path != null) {
                  final bytes = await File(res.single.path!).readAsBytes();
                  setState(() => _annotateImageBytes = Uint8List.fromList(bytes));
                }
              },
              icon: const Icon(Icons.add_photo_alternate),
              label: Text(_annotateImageBytes == null ? 'Pilih gambar' : 'Gambar dipilih'),
            ),
          ),
        ],
      ),
      if (_annotations.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('Anotasi yang ditambahkan: ${_annotations.length}',
            style: TextStyle(color: scheme.onSurfaceVariant)),
      ],
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: () {
          if (_annotateTextCtrl.text.isEmpty && _annotateImageBytes == null) return;
          setState(() {
            _annotations.add(AnnotationItem(
              page: 1,
              type: _annotateTextCtrl.text.isNotEmpty ? AnnotationType.text : AnnotationType.image,
              x: _annotateX,
              y: _annotateY,
              text: _annotateTextCtrl.text.isNotEmpty ? _annotateTextCtrl.text : null,
              fontSize: _annotateFontSize,
              color: _annotateColor,
              imageBytes: _annotateImageBytes,
              width: _annotateImageBytes != null ? 200 : null,
              height: _annotateImageBytes != null ? 200 : null,
            ));
            _annotateTextCtrl.clear();
            _annotateImageBytes = null;
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah anotasi'),
      ),
      _slider('Resolusi', '$_dpi dpi', 72, 200, _dpi,
          (v) => setState(() => _dpi = v.round())),
      _slider('Kualitas JPEG', '$_quality%', 30, 95, _quality,
          (v) => setState(() => _quality = v.round())),
      password != null
          ? TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Sandi (opsional)',
                prefixIcon: Icon(Icons.password),
              ),
            )
          : const SizedBox.shrink(),
    ];
  }

  List<Widget> _redactOptions(BuildContext context, String? password) {
    return [
      Text('Tambah area redaction (kotak hitam permanen):',
          style: TextStyle(fontWeight: FontWeight.w600)),
      _slider('Posisi X', '${_redactX.toInt()}', 0, 800, _redactX,
          (v) => setState(() => _redactX = v)),
      _slider('Posisi Y', '${_redactY.toInt()}', 0, 1100, _redactY,
          (v) => setState(() => _redactY = v)),
      _slider('Lebar', '${_redactWidth.toInt()}', 10, 600, _redactWidth,
          (v) => setState(() => _redactWidth = v)),
      _slider('Tinggi', '${_redactHeight.toInt()}', 10, 400, _redactHeight,
          (v) => setState(() => _redactHeight = v)),
      if (_redactions.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('Area redaction: ${_redactions.length}'),
      ],
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: () {
          setState(() {
            _redactions.add(RedactionArea(
              page: 1,
              x: _redactX,
              y: _redactY,
              width: _redactWidth,
              height: _redactHeight,
            ));
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah area redaction'),
      ),
      _slider('Resolusi', '$_dpi dpi', 72, 200, _dpi,
          (v) => setState(() => _dpi = v.round())),
      _slider('Kualitas JPEG', '$_quality%', 30, 95, _quality,
          (v) => setState(() => _quality = v.round())),
      password != null
          ? TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Sandi (opsional)',
                prefixIcon: Icon(Icons.password),
              ),
            )
          : const SizedBox.shrink(),
    ];
  }

  Widget _banner(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color))),
        ],
      ),
    );
  }

  Widget _resultCard(BuildContext context) {
    final r = _result!;
    final isPdf = r.outputPath.toLowerCase().endsWith('.pdf');
    final name = r.outputPath.split(RegExp(r'[/\\]')).last;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF16A34A)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Selesai',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (r.note != null) ...[
              const SizedBox(height: 4),
              Text(r.note!,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                if (isPdf)
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ViewerScreen(path: r.outputPath),
                      ),
                    ),
                    icon: const Icon(Icons.menu_book),
                    label: const Text('Buka'),
                  ),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: r.outputPath));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Path disalin')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Salin path'),
                ),
                if (r.extraFiles.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _showAll(r.extraFiles),
                    icon: const Icon(Icons.grid_view),
                    label: Text('Semua (${r.extraFiles.length})'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAll(List<String> files) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          for (final f in files)
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(f.split(RegExp(r'[/\\]')).last,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }
}