import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const List<_AccessibilityShortcut> _shortcuts = [
    _AccessibilityShortcut(icon: Icons.accessible_forward, label: 'Wheelchair'),
    _AccessibilityShortcut(icon: Icons.ramp_right, label: 'Ramp'),
    _AccessibilityShortcut(icon: Icons.elevator, label: 'Elevator'),
    _AccessibilityShortcut(icon: Icons.local_parking, label: 'Parking'),
    _AccessibilityShortcut(icon: Icons.wc, label: 'Restroom'),
  ];

  static const List<_NearbyPlace> _nearbyPlaces = [
    _NearbyPlace(
      name: 'City Hospital',
      category: 'Hospital',
      distance: '1.2 km',
      accessibilityScore: '92%',
      icon: Icons.local_hospital,
    ),
    _NearbyPlace(
      name: 'Green Park',
      category: 'Park',
      distance: '2.4 km',
      accessibilityScore: '84%',
      icon: Icons.park,
    ),
    _NearbyPlace(
      name: 'Metro Bank',
      category: 'Bank',
      distance: '3.1 km',
      accessibilityScore: '78%',
      icon: Icons.account_balance,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const _HomeHeader(),
            const SizedBox(height: 20),
            const _LocationSelector(),
            const SizedBox(height: 16),
            const _SearchBox(),
            const SizedBox(height: 24),
            const _SectionHeader(title: 'Quick accessibility'),
            const SizedBox(height: 14),
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _shortcuts.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _ShortcutButton(shortcut: _shortcuts[index]);
                },
              ),
            ),
            const SizedBox(height: 24),
            const _MapPreview(),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Nearby places',
              actionLabel: 'See all',
              onActionPressed: () {},
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 176,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _nearbyPlaces.length,
                separatorBuilder: (context, index) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  return _NearbyPlaceCard(place: _nearbyPlaces[index]);
                },
              ),
            ),
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
      children: [
        IconButton.filledTonal(
          onPressed: () {},
          icon: const Icon(Icons.menu),
          tooltip: 'Open menu',
        ),
        const Expanded(
          child: Text(
            'Accessibility Map',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton.filledTonal(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none),
          tooltip: 'Notifications',
        ),
      ],
    );
  }
}

class _LocationSelector extends StatelessWidget {
  const _LocationSelector();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Select current location',
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade500),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.location_on_outlined, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Current Location',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.keyboard_arrow_down, size: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox();

  @override
  Widget build(BuildContext context) {
    return TextField(
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 17),
      decoration: InputDecoration(
        hintText: 'Search accessible places',
        prefixIcon: const Icon(Icons.search, size: 30),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onActionPressed,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onActionPressed,
            child: Text(actionLabel!, style: const TextStyle(fontSize: 16)),
          ),
      ],
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton({required this.shortcut});

  final _AccessibilityShortcut shortcut;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Filter by ${shortcut.label}',
      child: SizedBox(
        width: 88,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              Container(
                height: 68,
                width: 68,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade500),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(shortcut.icon, size: 34),
              ),
              const SizedBox(height: 8),
              Text(
                shortcut.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Map preview showing nearby accessible places',
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey.shade500),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _MapPainter())),
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.near_me, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Near you',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyPlaceCard extends StatelessWidget {
  const _NearbyPlaceCard({required this.place});

  final _NearbyPlace place;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${place.name}, ${place.category}, ${place.distance} away, accessibility score ${place.accessibilityScore}',
      child: SizedBox(
        width: 164,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade500),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 54,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(place.icon, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${place.category} . ${place.distance}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(Icons.verified, size: 18),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${place.accessibilityScore} accessible',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final minorRoadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final roads = [
      [
        Offset(-20, size.height * 0.72),
        Offset(size.width + 20, size.height * 0.25),
      ],
      [
        Offset(size.width * 0.12, -20),
        Offset(size.width * 0.42, size.height + 20),
      ],
      [
        Offset(size.width * 0.72, -20),
        Offset(size.width * 0.5, size.height + 20),
      ],
      [
        Offset(-20, size.height * 0.28),
        Offset(size.width + 20, size.height * 0.6),
      ],
    ];

    for (final road in roads) {
      canvas.drawLine(road.first, road.last, roadPaint);
      canvas.drawLine(road.first, road.last, minorRoadPaint);
    }

    final markerPaint = Paint()..color = Colors.black87;
    final markerCenterPaint = Paint()..color = Colors.white;
    final markerPositions = [
      Offset(size.width * 0.2, size.height * 0.7),
      Offset(size.width * 0.56, size.height * 0.36),
      Offset(size.width * 0.78, size.height * 0.68),
      Offset(size.width * 0.88, size.height * 0.28),
    ];

    for (final position in markerPositions) {
      final marker = Path()
        ..addOval(Rect.fromCircle(center: position, radius: 16))
        ..moveTo(position.dx - 11, position.dy + 10)
        ..lineTo(position.dx, position.dy + 34)
        ..lineTo(position.dx + 11, position.dy + 10)
        ..close();

      canvas.drawPath(marker, markerPaint);
      canvas.drawCircle(position, 6, markerCenterPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AccessibilityShortcut {
  const _AccessibilityShortcut({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _NearbyPlace {
  const _NearbyPlace({
    required this.name,
    required this.category,
    required this.distance,
    required this.accessibilityScore,
    required this.icon,
  });

  final String name;
  final String category;
  final String distance;
  final String accessibilityScore;
  final IconData icon;
}
