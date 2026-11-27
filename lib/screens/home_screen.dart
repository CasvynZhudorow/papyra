import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../models/tool_def.dart';
import '../theme.dart';
import 'tool_screen.dart';
import 'viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tools = toolCatalog
        .where((t) =>
            _query.isEmpty ||
            t.title.toLowerCase().contains(_query.toLowerCase()) ||
            t.subtitle.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _header(context)),
          SliverToBoxAdapter(child: _search(context)),
          SliverToBoxAdapter(child: _categories(context)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.28,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _ToolCard(tool: tools[i]),
                childCount: tools.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: _Footer()),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
      decoration: BoxDecoration(
        gradient: brandGradient(),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset('assets/icon/icon.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Papyra',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4)),
                SizedBox(height: 2),
                Text('PDF lengkap, offline, di perangkatmu',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Tentang Papyra',
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'Papyra',
              applicationVersion: '0.1.0',
              applicationLegalese: 'Open source · MIT',
              children: const [
                Text(
                    'Semua proses berjalan lokal di perangkat. Tidak ada unggahan ke server.'),
              ],
            ),
            icon: const Icon(Icons.info_outline, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _search(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: 'Cari alat…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _query = ''),
                ),
        ),
      ),
    );
  }

  Widget _categories(BuildContext context) {
    if (_query.isNotEmpty) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (final c in ToolCategory.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text(categoryLabel(c)),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.tool});
  final ToolDef tool;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (tool.isOpener) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const _OpenPdfScreen(),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ToolScreen(tool: tool)),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary.withValues(alpha: 0.16),
                      scheme.primary.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(tool.icon, color: scheme.primary, size: 22),
              ),
              const Spacer(),
              Text(
                tool.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 3),
              Text(
                tool.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant, height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Text(
        'Papyra · dibangun dengan Flutter + PDFium · MIT License',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _OpenPdfScreen extends StatefulWidget {
  const _OpenPdfScreen();

  @override
  State<_OpenPdfScreen> createState() => _OpenPdfScreenState();
}

class _OpenPdfScreenState extends State<_OpenPdfScreen> {
  bool _picking = false;

  Future<void> _pickAndOpen() async {
    setState(() => _picking = true);
    try {
      final res = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (res != null && res.isNotEmpty && res.single.path != null) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ViewerScreen(path: res.single.path!),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Buka PDF')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.menu_book_outlined, size: 80, color: scheme.primary),
              const SizedBox(height: 24),
              Text(
                'Buka File PDF',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Pilih file PDF dari perangkat untuk dibuka di penampil.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _picking ? null : _pickAndOpen,
                icon: _picking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.folder_open),
                label: Text(_picking ? 'Memilih...' : 'Pilih PDF'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}