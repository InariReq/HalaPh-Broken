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

    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: FullscreenImagePreview(
              imagePath: trimmed,
              semanticLabel: semanticLabel,
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
    );
  }

  bool get _isNetworkImage =>
      imagePath.startsWith('http://') || imagePath.startsWith('https://');

  bool get _isLocalFile =>
      imagePath.startsWith('/') || imagePath.contains('\\');

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                          maxHeight: constraints.maxHeight,
                        ),
                        child: InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 5.0,
                          boundaryMargin: const EdgeInsets.all(96),
                          panEnabled: true,
                          scaleEnabled: true,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: _buildImage(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        'Image preview',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.24),
                          ),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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

          final expected = loadingProgress.expectedTotalBytes;
          final loaded = loadingProgress.cumulativeBytesLoaded;
          final progress = expected == null ? null : loaded / expected;

          return SizedBox(
            width: 96,
            height: 96,
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                value: progress,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => const _ImageError(),
      );
    }

    if (_isLocalFile) {
      return Image.file(
        File(imagePath),
        fit: BoxFit.contain,
        semanticLabel: semanticLabel,
        errorBuilder: (context, error, stackTrace) => const _ImageError(),
      );
    }

    return const _ImageError();
  }
}

class _ImageError extends StatelessWidget {
  const _ImageError();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.broken_image_outlined, size: 48, color: Colors.white70),
        SizedBox(height: 12),
        Text(
          'Could not load image',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Check your connection and try again.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }
}
