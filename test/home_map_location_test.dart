import 'dart:async';

import 'package:accesslink/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class _HomeLocationPlatform extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.whileInUse;
  int permissionRequests = 0;
  int positionRequests = 0;
  Future<Position> position = Future.value(_position(7.2906, 80.6337));

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    positionRequests++;
    return position;
  }
}

Position _position(double latitude, double longitude) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: DateTime(2026, 10, 11),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  late GeolocatorPlatform originalPlatform;
  late _HomeLocationPlatform platform;
  const places = <Map<String, dynamic>>[
    {
      'name': 'Colombo Park',
      'categoryName': 'Park',
      'latitude': 6.9271,
      'longitude': 79.8612,
    },
    {
      'name': 'Kandy Park',
      'categoryName': 'Park',
      'latitude': 7.291,
      'longitude': 80.637,
    },
  ];

  setUp(() {
    originalPlatform = GeolocatorPlatform.instance;
    platform = _HomeLocationPlatform();
    GeolocatorPlatform.instance = platform;
  });
  tearDown(() => GeolocatorPlatform.instance = originalPlatform);

  testWidgets(
    'home recentres on GPS and refreshes without permission prompts',
    (tester) async {
      final pendingPosition = Completer<Position>();
      platform.position = pendingPosition.future;
      await tester.pumpWidget(
        const MaterialApp(home: HomeScreen(initialPlaces: places)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byType(FlutterMap), 200);
      expect(
        tester
            .widget<FlutterMap>(find.byType(FlutterMap))
            .options
            .initialCenter,
        const LatLng(6.9271, 79.8612),
      );
      pendingPosition.complete(_position(7.2906, 80.6337));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FlutterMap>(find.byType(FlutterMap))
            .options
            .initialCenter,
        const LatLng(7.2906, 80.6337),
      );
      final map = find.byType(FlutterMap);
      expect(
        find.descendant(of: map, matching: find.byIcon(Icons.my_location)),
        findsOneWidget,
      );
      final markers = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers;
      expect(markers.first.point, const LatLng(7.2906, 80.6337));

      platform.position = Future.value(_position(6.9271, 79.8612));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        tester.widget<FlutterMap>(map).options.initialCenter,
        const LatLng(6.9271, 79.8612),
      );
      expect(platform.positionRequests, 2);
      expect(platform.permissionRequests, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('home hides the user marker when permission is missing', (
    tester,
  ) async {
    platform.permission = LocationPermission.denied;
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(initialPlaces: places)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(FlutterMap), 200);
    expect(
      find.descendant(
        of: find.byType(FlutterMap),
        matching: find.byIcon(Icons.my_location),
      ),
      findsNothing,
    );
    expect(platform.permissionRequests, 0);
    expect(platform.positionRequests, 0);
    await tester.scrollUntilVisible(
      find.text('Colombo Park'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('km away'), findsNothing);
    expect(find.textContaining('m away'), findsNothing);
    expect(find.textContaining('Near you'), findsNothing);
    expect(find.text('Park'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('home suggestions use GPS order and omit unknown distances', (
    tester,
  ) async {
    platform.position = Future.value(_position(7.2906, 80.6337));
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(
          initialPlaces: [
            ...places,
            {'name': 'Unknown Park', 'categoryName': 'Park', 'city': 'Kandy'},
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Kandy Park'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester.getTopLeft(find.text('Kandy Park')).dx,
      lessThan(tester.getTopLeft(find.text('Colombo Park')).dx),
    );
    expect(find.textContaining(RegExp(r' \d+ m away$')), findsOneWidget);
    expect(find.textContaining('km away'), findsOneWidget);
    expect(find.text('Park . Kandy'), findsOneWidget);
    expect(find.textContaining('Near you'), findsNothing);
    expect(platform.permissionRequests, 0);
    expect(tester.takeException(), isNull);
  });
}
