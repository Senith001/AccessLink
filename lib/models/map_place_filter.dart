bool matchesMapCategory(String placeCategory, String selectedCategory) {
  final selected = _normalize(selectedCategory);
  return selected == 'all' || _normalize(placeCategory) == selected;
}

String _normalize(String category) {
  final value = category.trim().toLowerCase().replaceAll('_', ' ');
  switch (value) {
    case 'restaurants':
      return 'restaurant';
    case 'hospitals':
      return 'hospital';
    case 'hotels':
      return 'hotel';
    case 'washrooms':
    case 'washroom':
    case 'toilet':
    case 'toilets':
      return 'toilet';
    case 'pharmacies':
      return 'pharmacy';
    case 'banks':
      return 'bank';
    case 'supermarkets':
      return 'supermarket';
    case 'bus stops':
      return 'bus stop';
    case 'schools':
      return 'school';
    default:
      return value;
  }
}