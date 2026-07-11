class TravelStop {
  final String destinationId;
  final String place;
  final String activity;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final String arrivalTime;
  final int durationMinutes;
  final double entryCost;
  final double foodCost;
  final String transportMode;
  final double transportCost;
  final String tip;
  final List<TravelSegment> segments;

  const TravelStop({
    required this.destinationId,
    required this.place,
    required this.activity,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    required this.arrivalTime,
    required this.durationMinutes,
    required this.entryCost,
    required this.foodCost,
    required this.transportMode,
    required this.transportCost,
    required this.tip,
    required this.segments,
  });

  factory TravelStop.fromJson(Map<String, dynamic> j) => TravelStop(
    destinationId: '${j['destinationId'] ?? ''}',
    place: '${j['place'] ?? ''}',
    activity: '${j['activity'] ?? ''}',
    latitude: _number(j['latitude']),
    longitude: _number(j['longitude']),
    imageUrl: '${j['imageUrl'] ?? ''}',
    arrivalTime: '${j['arrivalTime'] ?? ''}',
    durationMinutes: _number(j['durationMinutes']).round(),
    entryCost: _number(j['entryCost']),
    foodCost: _number(j['foodCost']),
    transportMode: '${j['transportMode'] ?? 'car'}',
    transportCost: _number(j['transportCost']),
    tip: '${j['tip'] ?? ''}',
    segments: ((j['segments'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => TravelSegment.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

class TravelSegment {
  final String mode;
  final String from;
  final String to;
  final int estimatedMinutes;
  final double estimatedCost;

  const TravelSegment({
    required this.mode,
    required this.from,
    required this.to,
    required this.estimatedMinutes,
    required this.estimatedCost,
  });

  factory TravelSegment.fromJson(Map<String, dynamic> j) => TravelSegment(
    mode: '${j['mode'] ?? 'car'}',
    from: '${j['from'] ?? ''}',
    to: '${j['to'] ?? ''}',
    estimatedMinutes: _number(j['estimatedMinutes']).round(),
    estimatedCost: _number(j['estimatedCost']),
  );
}

class TravelDay {
  final int day;
  final String theme;
  final List<TravelStop> stops;
  const TravelDay({
    required this.day,
    required this.theme,
    required this.stops,
  });
  factory TravelDay.fromJson(Map<String, dynamic> j) => TravelDay(
    day: _number(j['day']).round(),
    theme: '${j['theme'] ?? ''}',
    stops: ((j['stops'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => TravelStop.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

class TravelPlan {
  final int tripId;
  final String summary;
  final double totalEstimatedCost;
  final Map<String, double> budgetBreakdown;
  final List<TravelDay> days;
  final List<String> tips;
  const TravelPlan({
    required this.tripId,
    required this.summary,
    required this.totalEstimatedCost,
    required this.budgetBreakdown,
    required this.days,
    required this.tips,
  });
  factory TravelPlan.fromJson(Map<String, dynamic> j, {int tripId = 0}) {
    final rawBudget = Map<String, dynamic>.from(
      j['budgetBreakdown'] as Map? ?? {},
    );
    return TravelPlan(
      tripId: tripId,
      summary: '${j['summary'] ?? ''}',
      totalEstimatedCost: _number(j['totalEstimatedCost']),
      budgetBreakdown: rawBudget.map((k, v) => MapEntry(k, _number(v))),
      days: ((j['days'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => TravelDay.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      tips: ((j['tips'] as List?) ?? const []).map((e) => '$e').toList(),
    );
  }
  List<TravelStop> get allStops => days.expand((d) => d.stops).toList();
}

double _number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
