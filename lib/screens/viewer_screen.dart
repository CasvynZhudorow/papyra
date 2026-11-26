import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// Full-screen PDF viewer with page jump and zoom controls.
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key, required this.path, this.password});

  final String path;
  final String? password;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final _controller = PdfViewerController();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.path.split(RegExp(r'[/\\]')).last;
    return Scaffold(
      appBar: AppBar(
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: PdfViewer.file(
        widget.path,
        controller: _controller,
        passwordProvider: widget.password == null
            ? null
            : createSimplePasswordProvider(widget.password),
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
              Text('$_page / ${_pages == 0 ? "?" : _pages}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
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
}