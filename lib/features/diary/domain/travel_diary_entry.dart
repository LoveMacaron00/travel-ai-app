import 'dart:convert';

class DiarySubEntry {
  DiarySubEntry({
    required this.id,
    required this.time,
    required this.note,
    List<String> imageUrls = const [],
  }) : imageUrls = List.unmodifiable(imageUrls);

  factory DiarySubEntry.fromJson(Map<String, dynamic> json) {
    return DiarySubEntry(
      id: '${json['id'] ?? ''}',
      time:
          DateTime.tryParse('${json['time'] ?? ''}')?.toLocal() ??
          DateTime.now(),
      note: '${json['note'] ?? ''}',
      imageUrls:
          (json['imageUrls'] as List? ??
                  json['image_urls'] as List? ??
                  const [])
              .map((item) => '$item')
              .where((item) => item.isNotEmpty)
              .toList(),
    );
  }

  final String id;
  final DateTime time;
  final String note;
  final List<String> imageUrls;

  DiarySubEntry copyWith({
    DateTime? time,
    String? note,
    List<String>? imageUrls,
  }) => DiarySubEntry(
    id: id,
    time: time ?? this.time,
    note: note ?? this.note,
    imageUrls: imageUrls ?? this.imageUrls,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'time': time.toIso8601String(),
    'note': note,
    'imageUrls': imageUrls,
  };
}

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
    List<DiarySubEntry>? subEntries,
  }) : imageUrls = List.unmodifiable(
         imageUrls.isNotEmpty
             ? imageUrls
             : _gatherImagesFromSubEntries(subEntries),
       ),
       subEntries = List.unmodifiable(
         subEntries ?? _parseSubEntries(note, date, imageUrls),
       );

  factory TravelDiaryEntry.fromJson(Map<String, dynamic> json) {
    final date =
        DateTime.tryParse('${json['date'] ?? ''}')?.toLocal() ??
        DateTime.now();
    final rawImages =
        (json['imageUrls'] as List? ??
                json['image_urls'] as List? ??
                const [])
            .map((item) => '$item')
            .where((item) => item.isNotEmpty)
            .toList();
    final note = '${json['note'] ?? ''}';
    final parsedSub = _parseSubEntries(note, date, rawImages);

    return TravelDiaryEntry(
      id: '${json['id'] ?? ''}',
      date: date,
      lastSeenAt: DateTime.tryParse(
        '${json['lastSeenAt'] ?? json['last_seen_at'] ?? ''}',
      )?.toLocal(),
      title: '${json['title'] ?? ''}',
      note: note,
      province: '${json['province'] ?? ''}',
      insight: '${json['insight'] ?? ''}',
      imageUrls: rawImages,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      destinationId: int.tryParse(
        '${json['destinationId'] ?? json['destination_id'] ?? ''}',
      ),
      source: '${json['source'] ?? 'manual'}',
      subEntries: parsedSub,
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
  final List<DiarySubEntry> subEntries;

  static List<String> _gatherImagesFromSubEntries(
    List<DiarySubEntry>? subEntries,
  ) {
    if (subEntries == null || subEntries.isEmpty) return const [];
    final set = <String>{};
    for (final s in subEntries) {
      set.addAll(s.imageUrls);
    }
    return set.toList();
  }

  static List<DiarySubEntry> _parseSubEntries(
    String rawNote,
    DateTime fallbackTime,
    List<String> fallbackImages,
  ) {
    final trimmed = rawNote.trim();
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          final list = decoded
              .whereType<Map>()
              .map((m) => DiarySubEntry.fromJson(Map<String, dynamic>.from(m)))
              .toList();
          if (list.isNotEmpty) return list;
        }
      } catch (_) {}
    }
    if (trimmed.isNotEmpty || fallbackImages.isNotEmpty) {
      return [
        DiarySubEntry(
          id: 'sub_default_${fallbackTime.millisecondsSinceEpoch}',
          time: fallbackTime,
          note: rawNote,
          imageUrls: fallbackImages,
        ),
      ];
    }
    return const [];
  }

  bool get hasLocation => latitude != null && longitude != null;
  int get durationMinutes {
    if (lastSeenAt == null) return 0;
    final minutes = lastSeenAt!.difference(date).inMinutes;
    return minutes < 0 ? 0 : minutes;
  }

  String get displayNote {
    if (subEntries.isNotEmpty) {
      final texts = subEntries
          .map((s) => s.note.trim())
          .where((s) => s.isNotEmpty);
      if (texts.isNotEmpty) return texts.join('\n\n');
    }
    return note;
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
    List<DiarySubEntry>? subEntries,
  }) {
    final newSubEntries = subEntries ?? this.subEntries;
    final newImages = imageUrls ?? _gatherImagesFromSubEntries(newSubEntries);
    final finalImages = newImages.isNotEmpty ? newImages : this.imageUrls;
    final newNote =
        note ??
        (newSubEntries.isNotEmpty
            ? jsonEncode(newSubEntries.map((e) => e.toJson()).toList())
            : this.note);

    return TravelDiaryEntry(
      id: id,
      date: date ?? this.date,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      title: title ?? this.title,
      note: newNote,
      province: province ?? this.province,
      insight: insight ?? this.insight,
      imageUrls: finalImages,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      destinationId: destinationId ?? this.destinationId,
      source: source ?? this.source,
      subEntries: newSubEntries,
    );
  }

  TravelDiaryEntry addSubEntry(DiarySubEntry sub) {
    final updatedList = [...subEntries, sub];
    final allImages = _gatherImagesFromSubEntries(updatedList);
    return copyWith(
      subEntries: updatedList,
      note: jsonEncode(updatedList.map((e) => e.toJson()).toList()),
      imageUrls: allImages,
    );
  }

  TravelDiaryEntry updateSubEntry(DiarySubEntry updatedSub) {
    final updatedList = subEntries.map((item) {
      return item.id == updatedSub.id ? updatedSub : item;
    }).toList();
    final allImages = _gatherImagesFromSubEntries(updatedList);
    return copyWith(
      subEntries: updatedList,
      note: jsonEncode(updatedList.map((e) => e.toJson()).toList()),
      imageUrls: allImages,
    );
  }

  TravelDiaryEntry removeSubEntry(String subId) {
    final updatedList = subEntries.where((item) => item.id != subId).toList();
    final allImages = _gatherImagesFromSubEntries(updatedList);
    return copyWith(
      subEntries: updatedList,
      note: updatedList.isNotEmpty
          ? jsonEncode(updatedList.map((e) => e.toJson()).toList())
          : '',
      imageUrls: allImages,
    );
  }

  Map<String, dynamic> toJson() {
    final effectiveNote = subEntries.isNotEmpty
        ? jsonEncode(subEntries.map((e) => e.toJson()).toList())
        : note;
    final effectiveImages = subEntries.isNotEmpty
        ? _gatherImagesFromSubEntries(subEntries)
        : imageUrls;

    return {
      'id': id,
      'date': date.toIso8601String(),
      'lastSeenAt': lastSeenAt?.toIso8601String(),
      'title': title,
      'note': effectiveNote,
      'province': province,
      'insight': insight,
      'imageUrls': effectiveImages,
      'latitude': latitude,
      'longitude': longitude,
      'destinationId': destinationId,
      'source': source,
    };
  }
}
