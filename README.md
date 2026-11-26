# Papyra

**Papyra** — PDF platform open source untuk Windows dan Android. Semua proses berjalan
lokal di perangkat: tidak ada dokumen yang diunggah ke server.

Dibangun dengan Flutter + [pdfrx](https://pub.dev/packages/pdfrx) (PDFium) dan
[pdf](https://pub.dev/packages/pdf). UI/UX Material 3, terang/gelap otomatis,
responsif dari ponsel sampai desktop.

## Fitur

| Kategori | Alat |
|---|---|
| Rapikan | Gabung PDF, Ambil Halaman, Atur Halaman (putar/hapus), Putar Halaman |
| Konversi | Kompres PDF, PDF → Gambar (PNG/JPG), Gambar → PDF |
| Edit | Watermark teks transparan |
| Aman | Buka Kunci PDF (hapus sandi), Info Dokumen |

## Build

Butuh Flutter stable (3.50+ / Dart 3.14+).

```bash
flutter pub get
dart run flutter_launcher_icons     # generate ikon
flutter build windows --release     # Windows
flutter build apk --release         # Android
```

Platform scaffolding (`android/`, `windows/`) tidak disimpan di repo — CI membuatnya
dengan `flutter create` lalu mengembalikan `pubspec.yaml` yang asli.

## CI

GitHub Actions di `.github/workflows/build.yml`:

1. `test` — `flutter analyze` + `flutter test`
2. `windows` — build `.exe` (Developer Mode diaktifkan dulu, pdfrx butuh symlink)
3. `android` — build `.apk`

Artifact: `papyra-windows`, `papyra-android`.

## Lisensi

MIT. Lihat [LICENSE](LICENSE).