class PlaceMarker {
  final String id;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final String category;
  final String province;

  PlaceMarker({
    required this.id,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    required this.category,
    this.province = '',
  });
}
