enum TravelMode {
  driving('Personal vehicle', 'driving'),
  transit('Public transport', 'transit');

  const TravelMode(this.label, this.mapsValue);

  final String label;
  final String mapsValue;
}