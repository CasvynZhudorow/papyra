import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../services/pdf_service.dart';

/// Full-screen PDF reader: continuous view, thumbnail rail, text search,
/// page jump and zoom — the "Adobe Reader" surface of Papyra.
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key, required this.path, this.password});

  final String path;
  final String? password;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final _controller = PdfViewerController();
  final _thumbs = <int, Uint8List>{};
  final _searchCtrl = TextEditingController();
  List<({int page, String snippet})> _hits = const [];
  bool _searching = false;
  bool _thumbsOpen = false;
  int _page = 1;
  int _pages = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_sync);
  }

  void _sync() {
    final p = _controller.pageNumber ?? _page;
    final n = _controller.isReady ? _controller.document.pages.length : _pages;
    if (p != _page || n != _pages) {
      setState(() {
        _page = p;
        _pages = n;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_sync);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final q = _searchCtrl.text;
    if (q.trim().isEmpty) return;
    setState(() => _searching = true);
    try {
      final hits = await searchPdf(widget.path, q, password: widget.password);
      if (mounted) setState(() => _hits = hits);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Cari gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _jumpDialog() async {
    final ctrl = TextEditingController(text: '$_page');
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ke halaman'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Halaman (1–${_pages == 0 ? "?" : _pages})',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(int.tryParse(v)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(int.tryParse(ctrl.text)),
              child: const Text('Buka')),
        ],
      ),
    );
    ctrl.dispose();
    if (n != null && n >= 1) _controller.goToPage(pageNumber: n);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = widget.path.split(RegExp(r'[/\\]')).last;
    return Scaffold(
      appBar: AppBar(
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Cari teks',
            onPressed: _pages == 0 ? null : _searchDialog,
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Pratinjau halaman',
            onPressed: _pages == 0
                ? null
                : () => setState(() => _thumbsOpen = !_thumbsOpen),
            icon: Icon(_thumbsOpen
                ? Icons.view_agenda_outlined
                : Icons.view_agenda),
          ),
          IconButton(
            tooltip: 'Info dokumen',
            onPressed: () async {
              final r = await documentInfo(widget.path);
              if (!mounted) return;
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title:
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  content: Text(r.note ?? '-'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Tutup')),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: Row(
        children: [
          if (_thumbsOpen) _thumbnailRail(scheme),
          Expanded(
            child: PdfViewer.file(
              widget.path,
              controller: _controller,
              passwordProvider: widget.password == null
                  ? null
                  : createSimplePasswordProvider(widget.password),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Zoom out',
                icon: const Icon(Icons.remove),
                onPressed: _controller.isReady ? _controller.zoomDown : null,
              ),
              IconButton(
                tooltip: 'Zoom in',
                icon: const Icon(Icons.add),
                onPressed: _controller.isReady ? _controller.zoomUp : null,
              ),
              IconButton(
                tooltip: 'Halaman sebelumnya',
                icon: const Icon(Icons.chevron_left),
                onPressed: _page > 1
                    ? () => _controller.goToPage(pageNumber: _page - 1)
                    : null,
              ),
              InkWell(
                onTap: _pages == 0 ? null : _jumpDialog,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Text('$_page / ${_pages == 0 ? "?" : _pages}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              IconButton(
                tooltip: 'Halaman berikutnya',
                icon: const Icon(Icons.chevron_right),
                onPressed: _pages > 0 && _page < _pages
                    ? () => _controller.goToPage(pageNumber: _page + 1)
                    : null,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Muat ulang',
                icon: const Icon(Icons.refresh),
                onPressed: () => setState(() {}),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Thumbnails are rendered lazily and cached per page.
  /// shortcut: one page rendered per tile, no prefetch — fine up to a few
  /// hundred pages; add a scroll listener + cache eviction for bigger files.
  Widget _thumbnailRail(ColorScheme scheme) {
    return Container(
      width: 118,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _pages,
        itemBuilder: (ctx, i) {
          final n = i + 1;
          final cached = _thumbs[n];
          if (cached == null && !_thumbs.containsKey(n)) {
            _thumbs[n] = Uint8List(0);
            renderThumbnail(widget.path, n, password: widget.password)
                .then((bytes) {
              if (bytes != null && mounted) {
                setState(() => _thumbs[n] = bytes);
              }
            });
          }
          final ready = cached != null && cached.isNotEmpty;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _controller.goToPage(pageNumber: n),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: n == _page ? scheme.primary : scheme.outlineVariant,
                    width: n == _page ? 2 : 1,
                  ),
                ),
                padding: const EdgeInsets.all(3),
                child: Column(
                  children: [
                    SizedBox(
                      height: 84,
                      child: ready
                          ? Image.memory(cached, fit: BoxFit.contain)
                          : const Center(
                              child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))),
                    ),
                    Text('$n',
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _searchDialog() async {
    _searchCtrl.clear();
    setState(() => _hits = const []);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Cari di dokumen',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _searching ? null : _runSearch,
                ),
              ),
              onSubmitted: (_) => _runSearch(),
            ),
            const SizedBox(height: 8),
            if (_searching)
              const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              )
            else if (_hits.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Belum ada hasil',
                    style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.5),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final h in _hits)
                      ListTile(
                        leading: Text('${h.page}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4F46E5))),
                        title: Text(h.snippet,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _controller.goToPage(pageNumber: h.page);
                        },
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}