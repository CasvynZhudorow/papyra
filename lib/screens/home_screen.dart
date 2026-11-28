import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../models/tool_def.dart';
import '../services/recent_store.dart';
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
  List<RecentFile> _recent = const [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final r = await RecentStore.load();
    if (mounted) setState(() => _recent = r);
  }

  Future<void> _openPath(String path) async {
    await RecentStore.add(path);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ViewerScreen(path: path)),
    );
    await _loadRecent();
  }

  Future<void> _pickAndOpen() async {
    final res = await FilePickerPlatform.instance.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (res.isEmpty) return;
    await _openPath(res.single.path!);
  }

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
          SliverToBoxAdapter(child: _openCard(context)),
          if (_recent.isNotEmpty) ...[
            SliverToBoxAdapter(child: _recentHeader(context)),
            SliverToBoxAdapter(child: _recentList(context)),
          ],
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
                (context, i) => _ToolCard(
                  tool: tools[i],
                  onOpenPicker: _pickAndOpen,
                ),
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

  Widget _openCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary.withValues(alpha: 0.18),
                      scheme.primary.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.menu_book_outlined,
                    color: scheme.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Buka PDF',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Penampil lengkap: cari teks, pratinjau halaman, zoom',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _pickAndOpen,
                child: const Text('Pilih'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(
        children: [
          Text('Terakhir dibuka',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          TextButton(
            onPressed: () async {
              await RecentStore.clear();
              await _loadRecent();
            },
            child: const Text('Hapus semua'),
          ),
        ],
      ),
    );
  }

  Widget _recentList(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Card(
        child: Column(
          children: [
            for (final r in _recent)
              ListTile(
                leading: Icon(Icons.picture_as_pdf_outlined,
                    color: scheme.primary),
                title: Text(r.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                    '${r.openedAt.day}/${r.openedAt.month}/${r.openedAt.year}'),
                onTap: () => _openPath(r.path),
                trailing: IconButton(
                  tooltip: 'Hapus dari daftar',
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    await RecentStore.remove(r.path);
                    await _loadRecent();
                  },
                ),
              ),
          ],
        ),
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
  const _ToolCard({required this.tool, required this.onOpenPicker});
  final ToolDef tool;
  final Future<void> Function() onOpenPicker;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (tool.isOpener) {
            onOpenPicker();
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
