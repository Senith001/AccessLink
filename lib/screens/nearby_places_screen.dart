import 'package:flutter/material.dart';

import 'search_results_screen.dart';

class NearbyPlacesScreen extends StatelessWidget {
  const NearbyPlacesScreen({super.key, this.initialPlaces = const []});

  final List<Map<String, dynamic>> initialPlaces;

  @override
  Widget build(BuildContext context) {
    return SearchResultsScreen(
      title: 'Nearby places',
      initialPlaces: initialPlaces,
      initialNearbyOnly: true,
      enableFavorites: true,
      showSearchControls: false,
    );
  }
}
