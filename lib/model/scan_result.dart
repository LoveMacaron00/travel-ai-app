enum ScanMode { place, sign, food }

extension ScanModeDetails on ScanMode {
  String get apiValue => name;

  String get title => switch (this) {
    ScanMode.place => 'Explore a place',
    ScanMode.sign => 'Translate a sign',
    ScanMode.food => 'Discover Thai food',
  };

  String get description => switch (this) {
    ScanMode.place => 'History, culture, and visitor etiquette',
    ScanMode.sign => 'Read Thai text and translate it to English',
    ScanMode.food => 'Identify a dish and learn its cultural story',
  };

  String get userCaption => switch (this) {
    ScanMode.place => 'Explore this place',
    ScanMode.sign => 'Translate this Thai sign',
    ScanMode.food => 'Tell me about this Thai dish',
  };
}

class ScanSection {
  final String title;
  final String body;

  const ScanSection({required this.title, required this.body});

  factory ScanSection.fromJson(Map<String, dynamic> json) {
    return ScanSection(
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
    );
  }
}

class ScanCandidate {
  final String name;
  final double score;

  const ScanCandidate({required this.name, required this.score});

  factory ScanCandidate.fromJson(Map<String, dynamic> json) {
    return ScanCandidate(
      name: (json['name'] ?? '').toString(),
      score: (json['score'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ScanResult {
  final ScanMode mode;
  final String title;
  final String subtitle;
  final double confidence;
  final List<ScanSection> sections;
  final List<ScanCandidate> candidates;
  final String originalText;
  final String translatedText;

  const ScanResult({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.confidence,
    required this.sections,
    required this.candidates,
    required this.originalText,
    required this.translatedText,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final modeName = (json['mode'] ?? '').toString();
    final mode = ScanMode.values.firstWhere(
      (item) => item.apiValue == modeName,
      orElse: () => ScanMode.place,
    );
    return ScanResult(
      mode: mode,
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      sections: (json['sections'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => ScanSection.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      candidates: (json['candidates'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => ScanCandidate.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      originalText: (json['originalText'] ?? '').toString(),
      translatedText: (json['translatedText'] ?? '').toString(),
    );
  }
}
