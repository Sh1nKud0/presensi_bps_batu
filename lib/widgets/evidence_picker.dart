import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

Future<XFile?> pilihBukti(BuildContext context, {ImagePicker? picker}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text(
              'Lampirkan bukti',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Ambil foto'),
            subtitle: const Text('Gunakan kamera'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Pilih dari galeri'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return null;
  try {
    return await (picker ?? ImagePicker()).pickImage(
      source: source,
      imageQuality: 60,
      maxWidth: 1920,
      maxHeight: 1920,
      requestFullMetadata: false,
    );
  } on PlatformException catch (e) {
    if (context.mounted) {
      final denied = e.code.contains('denied') || e.code.contains('restricted');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            denied
                ? 'Izin kamera atau galeri ditolak. Aktifkan melalui pengaturan aplikasi.'
                : 'Kamera atau galeri tidak dapat dibuka. Silakan coba lagi.',
          ),
        ),
      );
    }
    return null;
  }
}
