import 'dart:convert';
import 'dart:io';

import 'package:myapp/model/travel_diary_entry.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TravelDiaryStore {
  TravelDiaryStore(this.accountKey);

  final String accountKey;

  String get _storageKey => 'travel_diary_entries_$accountKey';

  Future<List<TravelDiaryEntry>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final entries = decoded
          .whereType<Map>()
          .map(
            (item) =>
                TravelDiaryEntry.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
      entries.sort((a, b) => b.date.compareTo(a.date));
      return entries;
    } on FormatException {
      return [];
    }
  }

  Future<void> save(List<TravelDiaryEntry> entries) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<void> upsert(TravelDiaryEntry entry) async {
    final entries = await load();
    final index = entries.indexWhere((item) => item.id == entry.id);
    if (index < 0) {
      entries.add(entry);
    } else {
      entries[index] = entry;
    }
    entries.sort((a, b) => b.date.compareTo(a.date));
    await save(entries);
  }

  Future<String> preserveImage(String sourcePath, String entryId) async {
    if (sourcePath.isEmpty) return '';
    final source = File(sourcePath);
    if (!await source.exists()) return '';

    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/travel_diary');
    await directory.create(recursive: true);
    final dot = sourcePath.lastIndexOf('.');
    final extension = dot >= 0 ? sourcePath.substring(dot) : '.jpg';
    final destination = File('${directory.path}/$entryId$extension');
    if (source.absolute.path == destination.absolute.path) return sourcePath;
    await source.copy(destination.path);
    return destination.path;
  }

  Future<void> deleteImage(String imagePath) async {
    if (imagePath.isEmpty || !imagePath.contains('travel_diary')) return;
    final image = File(imagePath);
    if (await image.exists()) await image.delete();
  }

  Future<void> deleteImages(Iterable<String> imagePaths) async {
    for (final imagePath in imagePaths) {
      await deleteImage(imagePath);
    }
  }
}
