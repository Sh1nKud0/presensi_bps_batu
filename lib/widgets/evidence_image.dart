import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/app_data.dart';

/// Private evidence is fetched with bearer auth, never put in a public image URL.
class EvidenceImage extends StatefulWidget {
  final String reference;
  final BoxFit fit;
  final double? height;
  const EvidenceImage(
    this.reference, {
    super.key,
    this.fit = BoxFit.cover,
    this.height,
  });
  @override
  State<EvidenceImage> createState() => _EvidenceImageState();
}

class _EvidenceImageState extends State<EvidenceImage> {
  Future<Uint8List>? _bytes;
  void _load() {
    _bytes = widget.reference.startsWith('private:')
        ? appData.evidenceBytes(widget.reference)
        : null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EvidenceImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reference != oldWidget.reference) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null) {
      return Image.network(
        widget.reference,
        fit: widget.fit,
        height: widget.height,
        errorBuilder: (context, error, stack) =>
            const Text('Bukti tidak dapat dimuat.'),
      );
    }
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return TextButton(
            onPressed: () => setState(_load),
            child: const Text('Muat ulang bukti'),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Image.memory(
          snapshot.data!,
          fit: widget.fit,
          height: widget.height,
          errorBuilder: (context, error, stack) =>
              const Text('Format bukti tidak dapat ditampilkan.'),
        );
      },
    );
  }
}
