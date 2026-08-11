class TravelDiaryEntry {
  TravelDiaryEntry({
    required this.id,
    required this.date,
    required this.note,
    required this.province,
    this.title = '',
    this.insight = '',
    List<String> imageUrls = const [],
    this.latitude,
    this.longitude,
    this.lastSeenAt,
    this.destinationId,
    this.source = 'manual',
  }) : imageUrls = List.unmodifiable(imageUrls);

  factory TravelDiaryEntry.fromJson(Map<String, dynamic> json) {
    return TravelDiaryEntry(
      id: '${json['id'] ?? ''}',
      date:
          DateTime.tryParse('${json['date'] ?? ''}')?.toLocal() ??
          DateTime.now(),
      lastSeenAt: DateTime.tryParse(
        '${json['lastSeenAt'] ?? json['last_seen_at'] ?? ''}',
      )?.toLocal(),
      title: '${json['title'] ?? ''}',
      note: '${json['note'] ?? ''}',
      province: '${json['province'] ?? ''}',
      insight: '${json['insight'] ?? ''}',
      imageUrls:
          (json['imageUrls'] as List? ??
                  json['image_urls'] as List? ??
                  const [])
              .map((item) => '$item')
              .where((item) => item.isNotEmpty)
              .toList(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      destinationId: int.tryParse(
        '${json['destinationId'] ?? json['destination_id'] ?? ''}',
      ),
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
  final List<String> imageUrls;
  final double? latitude;
  final double? longitude;
  final int? destinationId;
  final String source;

  bool get hasLocation => latitude != null && longitude != null;
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
    'imageUrls': imageUrls,
    'latitude': latitude,
    'longitude': longitude,
    'destinationId': destinationId,
    'source': source,
  };
}
