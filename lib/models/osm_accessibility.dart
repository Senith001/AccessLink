enum OsmAccessStatus {
  available('Available'),
  limited('Limited'),
  unavailable('Unavailable'),
  unknown('Not confirmed');

  const OsmAccessStatus(this.label);
  final String label;
}

/// Interpret only explicit tags on the selected place, never nearby facilities.
class OsmAccessibility {
  const OsmAccessibility(this.tags);
  final Map<String, String> tags;

  static OsmAccessStatus status(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'yes':
      case 'designated':
        return OsmAccessStatus.available;
      case 'limited':
        return OsmAccessStatus.limited;
      case 'no':
        return OsmAccessStatus.unavailable;
      default:
        return OsmAccessStatus.unknown;
    }
  }

  OsmAccessStatus get wheelchair => status(tags['wheelchair']);
  OsmAccessStatus get toilet => status(tags['toilets:wheelchair']);
  OsmAccessStatus get elevator => status(tags['elevator']);

  OsmAccessStatus get parking {
    // capacity:disabled can describe rooms or seats on other kinds of places.
    if (tags['amenity'] != 'parking') return OsmAccessStatus.unknown;
    final value = tags['capacity:disabled'];
    final count = int.tryParse(value ?? '');
    if (count != null && count >= 0) {
      return count > 0
          ? OsmAccessStatus.available
          : OsmAccessStatus.unavailable;
    }
    return status(value);
  }

  String? get description =>
      tags['wheelchair:description:en'] ?? tags['wheelchair:description'];
}