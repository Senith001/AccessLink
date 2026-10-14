import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PhotoViewScreen extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;

  const PhotoViewScreen({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });

  static Route<void> route({
    required List<String> photos,
    int initialIndex = 0,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => PhotoViewScreen(
        photos: photos,
        initialIndex: initialIndex,
      ),
    );
  }

  @override
  State<PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends State<PhotoViewScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    // Handle empty photos defensively
    if (widget.photos.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
      });
    }
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

  @override
  Widget build(BuildContext context) {
    // Handle empty photos defensively
    if (widget.photos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'No photos',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: const Center(
          child: Text(
            'No photos available',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false,
        title: Semantics(
          label: 'Photo counter',
          liveRegion: true,
          child: Text(
            '${_currentIndex + 1} / ${widget.photos.length}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        actions: [
          Semantics(
            label: 'Close photo viewer',
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              iconSize: 24,
              constraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 48,
              ),
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemCount: widget.photos.length,
        itemBuilder: (context, index) {
          return Semantics(
            label: 'Photo ${index + 1} of ${widget.photos.length}',
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.photos[index],
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ),
                  errorWidget: (context, url, error) => const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          size: 48,
                          color: Colors.white70,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Image unavailable',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
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
    );
  }
}