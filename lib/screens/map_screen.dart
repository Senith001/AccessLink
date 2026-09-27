import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/place.dart';
import '../services/place_service.dart';
import '../services/travel_time_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final PlaceService _placeService = PlaceService();
  final TravelTimeService _travelTimeService = TravelTimeService();

  late Future<List<Place>> _placesFuture;

  @override
  void initState() {
    super.initState();
    _placesFuture = _placeService.getPlaces();
  }

  void _showPlaceDetails(Place place, Place startPlace) {
    final distanceKm = _travelTimeService.calculateDistanceKm(
      startLatitude: startPlace.latitude,
      startLongitude: startPlace.longitude,
      destinationLatitude: place.latitude,
      destinationLongitude: place.longitude,
    );

    final estimatedMinutes =
        _travelTimeService.calculateEstimatedTravelTime(
      distanceKm: distanceKm,
    );

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                place.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),

              Text(
                'Category: ${place.categoryName}',
              ),
              const SizedBox(height: 5),

              Text(
                'Address: ${place.address}',
              ),
              const SizedBox(height: 5),

              Text(
                'Location: ${place.latitude}, ${place.longitude}',
              ),

              const Divider(height: 30),

              const Text(
                'Journey Estimate',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Distance: ${distanceKm.toStringAsFixed(2)} km',
              ),
              const SizedBox(height: 5),

              Text(
                'Estimated Travel Time: $estimatedMinutes minutes',
              ),
              const SizedBox(height: 5),

              const Text(
                'Based on an average travel speed of 40 km/h',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Public Places'),
      ),
      body: FutureBuilder<List<Place>>(
        future: _placesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final places = snapshot.data ?? [];

          if (places.isEmpty) {
            return const Center(
              child: Text('No places found'),
            );
          }

          final startPlace = places.first;

          return FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(
                startPlace.latitude,
                startPlace.longitude,
              ),
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.accesslink',
              ),
              MarkerLayer(
                markers: places.map((place) {
                  return Marker(
                    point: LatLng(
                      place.latitude,
                      place.longitude,
                    ),
                    width: 50,
                    height: 50,
                    child: GestureDetector(
                      onTap: () {
                        _showPlaceDetails(
                          place,
                          startPlace,
                        );
                      },
                      child: const Icon(
                        Icons.location_pin,
                        size: 45,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}