import 'package:flutter/material.dart';

enum ToolCategory { organize, convert, secure, edit }

enum PageAction { moveUp, moveDown, rotate, duplicate, delete }

class ToolDef {
  const ToolDef({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.category,
    this.multiInput = false,
    this.needsPageList = false,
    this.isOpener = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final ToolCategory category;
  final bool multiInput;
  final bool needsPageList;
  final bool isOpener;
}

const toolCatalog = <ToolDef>[
  ToolDef(
    id: 'open',
    title: 'Buka PDF',
    subtitle: 'Buka & lihat file PDF dari perangkat',
    icon: Icons.menu_book_outlined,
    category: ToolCategory.organize,
    isOpener: true,
  ),
  ToolDef(
    id: 'merge',
    title: 'Gabung PDF',
    subtitle: 'Satukan beberapa PDF jadi satu',
    icon: Icons.merge_type,
    category: ToolCategory.organize,
    multiInput: true,
  ),
  ToolDef(
    id: 'extract',
    title: 'Ambil Halaman',
    subtitle: 'Ekstrak halaman tertentu',
    icon: Icons.content_cut,
    category: ToolCategory.organize,
    needsPageList: true,
  ),
  ToolDef(
    id: 'organize',
    title: 'Atur Halaman',
    subtitle: 'Urutkan, putar, hapus, gandakan',
    icon: Icons.dashboard_customize,
    category: ToolCategory.organize,
    needsPageList: true,
  ),
  ToolDef(
    id: 'rotate',
    title: 'Putar Halaman',
    subtitle: '90° / 180° / 270°',
    icon: Icons.rotate_right,
    category: ToolCategory.organize,
    needsPageList: true,
  ),
  ToolDef(
    id: 'compress',
    title: 'Kompres PDF',
    subtitle: 'Kecilkan ukuran berkas',
    icon: Icons.compress,
    category: ToolCategory.convert,
  ),
  ToolDef(
    id: 'pdf2img',
    title: 'PDF ke Gambar',
    subtitle: 'Render tiap halaman jadi PNG/JPG',
    icon: Icons.image_outlined,
    category: ToolCategory.convert,
  ),
  ToolDef(
    id: 'img2pdf',
    title: 'Gambar ke PDF',
    subtitle: 'Susun foto jadi satu PDF',
    icon: Icons.photo_library_outlined,
    category: ToolCategory.convert,
    multiInput: true,
  ),
  ToolDef(
    id: 'watermark',
    title: 'Watermark',
    subtitle: 'Tulisan transparan di semua halaman',
    icon: Icons.branding_watermark,
    category: ToolCategory.edit,
  ),
  ToolDef(
    id: 'annotate',
    title: 'Teks & Gambar',
    subtitle: 'Tambah teks, gambar, tanda tangan',
    icon: Icons.edit_note,
    category: ToolCategory.edit,
  ),
  ToolDef(
    id: 'redact',
    title: 'Coret (Redact)',
    subtitle: 'Sembunyikan teks sensitif permanen',
    icon: Icons.content_copy_off,
    category: ToolCategory.edit,
  ),
  ToolDef(
    id: 'decrypt',
    title: 'Buka Kunci PDF',
    subtitle: 'Hapus sandi dari PDF terenkripsi',
    icon: Icons.lock_open,
    category: ToolCategory.secure,
  ),
  ToolDef(
    id: 'metadata',
    title: 'Info Dokumen',
    subtitle: 'Jumlah halaman & ukuran berkas',
    icon: Icons.info_outline,
    category: ToolCategory.secure,
  ),
];

String categoryLabel(ToolCategory c) => switch (c) {
      ToolCategory.organize => 'Rapikan',
      ToolCategory.convert => 'Konversi',
      ToolCategory.secure => 'Aman',
      ToolCategory.edit => 'Edit',
    };