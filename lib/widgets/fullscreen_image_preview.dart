import 'dart:io';

import 'package:flutter/material.dart';

class FullscreenImagePreview extends StatelessWidget {
  final String imagePath;
  final String? semanticLabel;

  const FullscreenImagePreview({
    super.key,
    required this.imagePath,
    this.semanticLabel,
  });

  static Future<void> open(
    BuildContext context, {
    required String imagePath,
    String? semanticLabel,
  }) {
    final trimmed = imagePath.trim();
    if (trimmed.isEmpty) return Future.value();

    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: FullscreenImagePreview(
              imagePath: trimmed,
              semanticLabel: semanticLabel,
            ),
          );
        },
      ),
    );
  }

  bool get _isNetworkImage =>
      imagePath.startsWith('http://') || imagePath.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.96),
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: Center(
                child: GestureDetector(
                  onTap: () {},
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5.0,
                    panEnabled: true,
                    child: _buildImage(),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.48),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (_isNetworkImage) {
      return Image.network(
        imagePath,
        fit: BoxFit.contain,
        semanticLabel: semanticLabel,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const SizedBox(
            width: 72,
            height: 72,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const _ImageError();
        },
      );
    }

    final file = File(imagePath);
    return Image.file(
      file,
      fit: BoxFit.contain,
      semanticLabel: semanticLabel,
      errorBuilder: (context, error, stackTrace) => const _ImageError(),
    );
  }
}

class _ImageError extends StatelessWidget {
  const _ImageError();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.broken_image_outlined, size: 44, color: Colors.white70),
        SizedBox(height: 10),
        Text(
          'Image unavailable',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
