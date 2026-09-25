import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/database/firestore_collections.dart';
import '../models/place.dart';
import 'search_results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialPlaces = const []});

  final List<Map<String, dynamic>> initialPlaces;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Place> _places = const [];
  bool _isLoadingPlaces = true;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    if (widget.initialPlaces.isNotEmpty) {
      setState(() {
        _places = widget.initialPlaces
            .map(Place.fromData)
            .whereType<Place>()
            .toList();
        _isLoadingPlaces = false;
      });
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.places)
          .get();
      if (!mounted) return;
      setState(() {
        _places = snapshot.docs
            .map(Place.fromFirestore)
            .whereType<Place>()
            .toList();
        _isLoadingPlaces = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingPlaces = false);
    }
  }

  void _openSearch(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(
          initialPlaces: widget.initialPlaces,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF62A4C6),
      body: SafeArea(
        child: Column(
          children: [
            const _HomeHeader(),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(36),
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 18),
                  children: [
                    _SearchLauncher(onTap: () => _openSearch(context)),
                    const SizedBox(height: 10),
                    const _PromoBanner(),
                    const SizedBox(height: 10),
                    const _LocationSelector(),
                    const SizedBox(height: 12),
                    const Text(
                      'Quick accessibility',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _AccessibilityShortcuts(),
                    const SizedBox(height: 14),
                    const _MapPreview(),
                    const SizedBox(height: 14),
                    const Text(
                      'Nearby places',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_isLoadingPlaces)
                      const SizedBox(
                        height: 150,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_places.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text('No nearby places available yet.'),
                        ),
                      )
                    else
                      SizedBox(
                        height: 160,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _places.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) => _NearbyPlaceCard(
                            place: _places[index],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const _HomeBottomBar(),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.menu),
          color: Colors.black,
          tooltip: 'Open menu',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white24,
            side: const BorderSide(color: Colors.white70),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const Text(
          'Accessibility map',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 27,
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none),
          color: Colors.black,
          tooltip: 'Notifications',
        ),
      ],
    );
  }
}

class _SearchLauncher extends StatelessWidget {
  const _SearchLauncher({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Search accessible places',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: InputDecorator(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search, color: Color(0xFF009BC2)),
            suffixIcon: const Icon(Icons.arrow_forward_ios, size: 16),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFFE4E7EA)),
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          child: const Text(
            'Search accessible places',
            style: TextStyle(fontSize: 17, color: Color(0xFF53636C)),
          ),
        ),
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8CFF76), Color(0xFF7CF36E)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find Accessible\nPlaces Near You',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.05,
                    ),
                  ),
                  Spacer(),
                  Text(
                    'Discover wheelchair-friendly locations\nnear you.',
                    style: TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8CFF76), Color(0xFF338BA9)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.accessible_forward,
                size: 58,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationSelector extends StatelessWidget {
  const _LocationSelector();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE4E7EA)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Row(
        children: [
          Icon(Icons.location_on_outlined, color: Color(0xFF009BC2)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Current Location',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          Icon(Icons.keyboard_arrow_down),
        ],
      ),
    );
  }
}

class _AccessibilityShortcuts extends StatelessWidget {
  const _AccessibilityShortcuts();

  static const _items = <(IconData, String)>[
    (Icons.accessible_forward, 'Wheelchair'),
    (Icons.ramp_right, 'Ramp'),
    (Icons.elevator, 'Elevator'),
    (Icons.local_parking, 'Parking'),
    (Icons.wc, 'Restroom'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final item in _items)
          Column(
            children: [
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F2F7),
                  border: Border.all(color: const Color(0xFFD3E1E8)),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.$1, color: const Color(0xFF53636C)),
              ),
              const SizedBox(height: 6),
              Text(item.$2, style: const TextStyle(fontSize: 11)),
            ],
          ),
      ],
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EEF0),
        border: Border.all(color: const Color(0xFFDDE4E7)),
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(painter: _MapPainter()),
    );
  }
}

class _NearbyPlaceCard extends StatelessWidget {
  const _NearbyPlaceCard({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 164,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaceDetailsScreen(place: place),
          ),
        ),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE4E7EA)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 52,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F2F7),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(place.icon, color: const Color(0xFF62A4C6)),
              ),
              const SizedBox(height: 10),
              Text(
                place.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${place.category} . ${place.distance}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFFCBD5D8)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final detailPaint = Paint()
      ..color = const Color(0xFFEFF4F5)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final roads = [
      [Offset(-20, size.height * .72), Offset(size.width + 20, size.height * .25)],
      [Offset(size.width * .12, -20), Offset(size.width * .42, size.height + 20)],
      [Offset(size.width * .72, -20), Offset(size.width * .5, size.height + 20)],
      [Offset(-20, size.height * .28), Offset(size.width + 20, size.height * .6)],
    ];

    for (final road in roads) {
      canvas.drawLine(road.first, road.last, roadPaint);
      canvas.drawLine(road.first, road.last, detailPaint);
    }

    final markerPaint = Paint()..color = const Color(0xFFFF0033);
    final centerPaint = Paint()..color = Colors.white;
    for (final position in [
      Offset(size.width * .2, size.height * .7),
      Offset(size.width * .56, size.height * .36),
      Offset(size.width * .78, size.height * .68),
    ]) {
      canvas.drawCircle(position, 14, markerPaint);
      canvas.drawCircle(position, 5, centerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HomeBottomBar extends StatelessWidget {
  const _HomeBottomBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _BottomBarItem(icon: Icons.home_outlined, label: 'Home', active: true),
          _BottomBarItem(icon: Icons.accessibility_new, label: 'Access'),
          _BottomBarItem(icon: Icons.notifications_none, label: 'Alerts'),
          _BottomBarItem(icon: Icons.person_outline, label: 'Profile'),
        ],
      ),
    );
  }
}

class _BottomBarItem extends StatelessWidget {
  const _BottomBarItem({required this.icon, required this.label, this.active = false});

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF2C4552) : const Color(0xFF4F5962);
    return Container(
      padding: active
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 5)
          : EdgeInsets.zero,
      decoration: active
          ? BoxDecoration(
              color: const Color(0xFF3A99BC),
              borderRadius: BorderRadius.circular(18),
            )
          : null,
      child: Row(
        children: [
          Icon(icon, size: 24, color: color),
          if (active) ...[
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ],
      ),
    );
  }
}
