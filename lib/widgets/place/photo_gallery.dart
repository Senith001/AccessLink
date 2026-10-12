import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'photo_viewer_dialog.dart';

class PhotoGallery extends StatefulWidget {
  final List<String> photos;
  final double? height;
  final VoidCallback? onAddPhoto;

  const PhotoGallery({
    super.key,
    required this.photos,
    this.height,
    this.onAddPhoto,
  });

  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveHeight = widget.height ?? 220.0;

    if (widget.photos.isEmpty) {
      return Container(
        height: effectiveHeight,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_outlined,
                size: 56,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'No photos available',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.onAddPhoto != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: widget.onAddPhoto,
                  icon: const Icon(Icons.add_a_photo, size: 18),
                  label: const Text('Add First Photo'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          height: effectiveHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              PageView.builder(
                itemCount: widget.photos.length,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemBuilder: (context, index) {
                  return Semantics(
                    button: true,
                    label:
                        'Photo ${index + 1} of ${widget.photos.length}. Tap to view full screen.',
                    child: InkWell(
                      onTap: () => PhotoViewerDialog.show(
                        context,
                        photos: widget.photos,
                        initialIndex: index,
                      ),
                      child: CachedNetworkImage(
                        imageUrl: widget.photos[index],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: colorScheme.surface,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: colorScheme.surface,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Image unavailable',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: colorScheme.onSurface.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Page indicator badge
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentPage + 1} / ${widget.photos.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Enlarge hint icon
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fullscreen,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
