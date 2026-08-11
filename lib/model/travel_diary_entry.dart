class TravelDiaryEntry {
  TravelDiaryEntry({
    required this.id,
    required this.date,
    required this.note,
    required this.province,
    this.title = '',
    this.insight = '',
    List<String> imagePaths = const [],
    List<String> imageUrls = const [],
    this.latitude,
    this.longitude,
    this.lastSeenAt,
    this.destinationId,
    this.source = 'manual',
    String imagePath = '',
  }) : imagePaths = imagePaths.isEmpty && imagePath.isNotEmpty
           ? [imagePath]
           : List.unmodifiable(imagePaths),
       imageUrls = List.unmodifiable(imageUrls);

  factory TravelDiaryEntry.fromJson(Map<String, dynamic> json) {
    final paths = (json['imagePaths'] as List? ?? const [])
        .map((item) => '$item')
        .where((item) => item.isNotEmpty)
        .toList();
    final legacyPath = '${json['imagePath'] ?? ''}';
    if (paths.isEmpty && legacyPath.isNotEmpty) paths.add(legacyPath);

    return TravelDiaryEntry(
      id: '${json['id'] ?? ''}',
      date: DateTime.tryParse('${json['date'] ?? ''}') ?? DateTime.now(),
      lastSeenAt: DateTime.tryParse('${json['lastSeenAt'] ?? ''}'),
      title: '${json['title'] ?? ''}',
      note: '${json['note'] ?? ''}',
      province: '${json['province'] ?? ''}',
      insight: '${json['insight'] ?? ''}',
      imagePaths: paths,
      imageUrls: (json['imageUrls'] as List? ?? const [])
          .map((item) => '$item')
          .where((item) => item.isNotEmpty)
          .toList(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      destinationId: int.tryParse('${json['destinationId'] ?? ''}'),
      source: '${json['source'] ?? 'manual'}',
    );
  }

  final String id;
  final DateTime date;
  final DateTime? lastSeenAt;
  final String title;
  final String note;
  final String province;
  final String insight;
  final List<String> imagePaths;
  final List<String> imageUrls;
  final double? latitude;
  final double? longitude;
  final int? destinationId;
  final String source;

  bool get hasLocation => latitude != null && longitude != null;
  String get imagePath => imagePaths.isEmpty ? '' : imagePaths.first;
  int get durationMinutes {
    if (lastSeenAt == null) return 0;
    final minutes = lastSeenAt!.difference(date).inMinutes;
    return minutes < 0 ? 0 : minutes;
  }

  TravelDiaryEntry copyWith({
    DateTime? date,
    DateTime? lastSeenAt,
    String? title,
    String? note,
    String? province,
    String? insight,
    List<String>? imagePaths,
    List<String>? imageUrls,
    double? latitude,
    double? longitude,
    int? destinationId,
    String? source,
  }) => TravelDiaryEntry(
    id: id,
    date: date ?? this.date,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    title: title ?? this.title,
    note: note ?? this.note,
    province: province ?? this.province,
    insight: insight ?? this.insight,
    imagePaths: imagePaths ?? this.imagePaths,
    imageUrls: imageUrls ?? this.imageUrls,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    destinationId: destinationId ?? this.destinationId,
    source: source ?? this.source,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'lastSeenAt': lastSeenAt?.toIso8601String(),
    'title': title,
    'note': note,
    'province': province,
    'insight': insight,
    'imagePaths': imagePaths,
    'imageUrls': imageUrls,
    'latitude': latitude,
    'longitude': longitude,
    'destinationId': destinationId,
    'source': source,
  };
}
