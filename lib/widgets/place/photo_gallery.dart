import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../screens/photo_view_screen.dart';

class PhotoGallery extends StatefulWidget {
  final List<String> photos;
  final double? height;
  final bool enableFullScreen;

  const PhotoGallery({
    super.key,
    required this.photos,
    this.height,
    this.enableFullScreen = true,
  });

  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _openFullScreen(int index) {
    if (widget.enableFullScreen) {
      Navigator.push(
        context,
        PhotoViewScreen.route(
          photos: widget.photos,
          initialIndex: index,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveHeight = widget.height ?? 200.0;

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
                Icons.image,
                size: 64,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 12),
              Text(
                'No photos available',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: effectiveHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: widget.photos.length,
            itemBuilder: (context, index) {
              final imageWidget = CachedNetworkImage(
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
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Image unavailable',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              if (widget.enableFullScreen) {
                return Semantics(
                  label: 'Photo ${index + 1} of ${widget.photos.length}',
                  child: GestureDetector(
                    onTap: () => _openFullScreen(index),
                    child: imageWidget,
                  ),
                );
              } else {
                return Semantics(
                  label: 'Photo ${index + 1} of ${widget.photos.length}',
                  child: imageWidget,
                );
              }
            },
          ),
          
          // Page indicator overlay (only shown when there are multiple photos)
          if (widget.photos.length > 1)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentIndex + 1}/${widget.photos.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}