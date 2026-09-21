/// จุดแวะหนึ่งจุดในแผน ซึ่งเก็บทั้งข้อมูลสำหรับการ์ดและข้อมูลนำทาง
class TravelStop {
  final String destinationId;
  final String place;
  final String province;
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

  /// จุดแวะพักระหว่างทางจาก OpenStreetMap (osm:...) — ไม่ใช่ destinations ใน DB
  /// UI ใช้แยกหมุด/ซ่อนปุ่มนำทางแบบเก็บค่าใช้จ่าย ส่วน PUT กลับ server ใช้คง flag ผ่าน toJson
  final bool isRestStop;
  final String restType;

  /// ประเภท stop จาก server: 'rest' (พักรายทาง) / 'overnight' (ที่พักค้างคืน) / '' (สถานที่เที่ยว)
  final String stopType;

  /// ที่พักค้างคืนท้ายวัน — แยกสี/ไอคอนจากจุดพักรายทาง
  bool get isOvernight => stopType == 'overnight';

  /// เวลาเปิด-ปิดจาก DB ("08:00"/"18:00") — '' คือไม่ระบุ
  /// server เติมให้ตอน normalize (ดู planPlaceNormalizer) เพื่อให้ UI โชว์ + ตรวจนอกเวลาเปิดได้
  /// PUT กลับ server คงค่าผ่าน toJson (server ใช้ตรวจซ้ำตอน chainAllDaysPreservingOrder)
  final String openingTime;
  final String closingTime;

  const TravelStop({
    required this.destinationId,
    required this.place,
    this.province = '',
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
    this.isRestStop = false,
    this.restType = '',
    this.stopType = '',
    this.openingTime = '',
    this.closingTime = '',
  });

  factory TravelStop.fromJson(Map<String, dynamic> j) => TravelStop(
    destinationId: '${j['destinationId'] ?? ''}',
    place: '${j['place'] ?? ''}',
    province: '${j['province'] ?? j['provinceName'] ?? ''}',
    activity: '${j['activity'] ?? ''}',
    latitude: _number(j['latitude']),
    longitude: _number(j['longitude']),
    imageUrl: _planImageUrl(j['imageUrl']),
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
    isRestStop:
        j['isRestStop'] == true || '${j['destinationId'] ?? ''}'.startsWith('osm:'),
    restType: '${j['restType'] ?? ''}',
    stopType: '${j['stopType'] ?? ''}',
    openingTime: '${j['openingTime'] ?? j['opening_time'] ?? ''}',
    closingTime: '${j['closingTime'] ?? j['closing_time'] ?? ''}',
  );

  Map<String, dynamic> toJson() => {
    'destinationId': destinationId,
    'place': place,
    'province': province,
    'activity': activity,
    'latitude': latitude,
    'longitude': longitude,
    'imageUrl': imageUrl,
    'arrivalTime': arrivalTime,
    'durationMinutes': durationMinutes,
    'entryCost': entryCost,
    'foodCost': foodCost,
    'transportMode': transportMode,
    'transportCost': transportCost,
    'tip': tip,
    'segments': segments.map((e) => e.toJson()).toList(),
    if (isRestStop) 'isRestStop': true,
    if (restType.isNotEmpty) 'restType': restType,
    if (stopType.isNotEmpty) 'stopType': stopType,
    if (openingTime.isNotEmpty) 'openingTime': openingTime,
    if (closingTime.isNotEmpty) 'closingTime': closingTime,
  };

  TravelStop copyWith({
    String? destinationId,
    String? place,
    String? province,
    String? activity,
    double? latitude,
    double? longitude,
    String? imageUrl,
    String? arrivalTime,
    int? durationMinutes,
    double? entryCost,
    double? foodCost,
    String? transportMode,
    double? transportCost,
    String? tip,
    List<TravelSegment>? segments,
    bool? isRestStop,
    String? restType,
    String? stopType,
    String? openingTime,
    String? closingTime,
  }) => TravelStop(
    destinationId: destinationId ?? this.destinationId,
    place: place ?? this.place,
    province: province ?? this.province,
    activity: activity ?? this.activity,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    imageUrl: imageUrl ?? this.imageUrl,
    arrivalTime: arrivalTime ?? this.arrivalTime,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    entryCost: entryCost ?? this.entryCost,
    foodCost: foodCost ?? this.foodCost,
    transportMode: transportMode ?? this.transportMode,
    transportCost: transportCost ?? this.transportCost,
    tip: tip ?? this.tip,
    segments: segments ?? this.segments,
    isRestStop: isRestStop ?? this.isRestStop,
    restType: restType ?? this.restType,
    stopType: stopType ?? this.stopType,
    openingTime: openingTime ?? this.openingTime,
    closingTime: closingTime ?? this.closingTime,
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

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'from': from,
    'to': to,
    'estimatedMinutes': estimatedMinutes,
    'estimatedCost': estimatedCost,
  };
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

  Map<String, dynamic> toJson() => {
    'day': day,
    'theme': theme,
    'stops': stops.map((e) => e.toJson()).toList(),
  };
}

class TravelReturnLeg {
  final String from;
  final String to;
  final double distanceKm;
  final int estimatedMinutes;
  final double estimatedCost;
  final String mode;

  const TravelReturnLeg({
    required this.from,
    required this.to,
    required this.distanceKm,
    required this.estimatedMinutes,
    required this.estimatedCost,
    required this.mode,
  });

  factory TravelReturnLeg.fromJson(Map<String, dynamic> j) => TravelReturnLeg(
    from: '${j['from'] ?? ''}',
    to: '${j['to'] ?? ''}',
    distanceKm: _number(j['distanceKm'] ?? j['distance_km'] ?? j['km']),
    estimatedMinutes: _number(
      j['estimatedMinutes'] ?? j['estimated_minutes'],
    ).round(),
    estimatedCost: _number(j['estimatedCost'] ?? j['estimated_cost']),
    mode: '${j['mode'] ?? 'car'}',
  );

  Map<String, dynamic> toJson() => {
    'from': from,
    'to': to,
    'distanceKm': distanceKm,
    'estimatedMinutes': estimatedMinutes,
    'estimatedCost': estimatedCost,
    'mode': mode,
  };
}

class TravelPlan {
  final int tripId;

  /// ชื่อแผนที่ผู้ใช้ตั้งเอง — '' คือยังไม่ตั้ง ให้ UI fallback เป็น destination/province
  /// เก็บแยกจาก plan_data (มาจากคอลัมน์ trips.title) จึงไม่ถูกส่งกลับใน toJson
  final String title;
  final String summary;
  final double totalEstimatedCost;
  final Map<String, double> budgetBreakdown;
  final List<TravelDay> days;
  final List<String> tips;

  /// คำเตือนจากระบบจัดตาราง (วันแน่น/ระยะไกลเกิน) — server คำนวณให้
  /// แผนเก่าที่ไม่มี field นี้ถือว่าไม่มีคำเตือน
  final List<String> warnings;

  /// วันที่เริ่มทริป "YYYY-MM-DD" จากคอลัมน์ trips.start_date — '' คือไม่ระบุ
  /// client ส่ง start_date ตอน POST /trips; server ส่งกลับใน GET /trips/:id ข้าง plan_data
  /// ใช้แสดงหัวข้อแต่ละวันเป็นวันที่จริง (start + day - 1) แม้เปิดแผนเก่าจาก Profile
  final String startDate;

  /// ขากลับจากจุดสุดท้ายไปยังจุดเริ่มต้น — null คือแผนเก่าที่ server ยังไม่ได้คำนวณ
  final TravelReturnLeg? returnLeg;
  const TravelPlan({
    required this.tripId,
    this.title = '',
    required this.summary,
    required this.totalEstimatedCost,
    required this.budgetBreakdown,
    required this.days,
    required this.tips,
    this.warnings = const [],
    this.startDate = '',
    this.returnLeg,
  });

  TravelPlan copyWith({
    int? tripId,
    String? title,
    String? summary,
    double? totalEstimatedCost,
    Map<String, double>? budgetBreakdown,
    List<TravelDay>? days,
    List<String>? tips,
    List<String>? warnings,
    String? startDate,
    TravelReturnLeg? returnLeg,
  }) => TravelPlan(
    tripId: tripId ?? this.tripId,
    title: title ?? this.title,
    summary: summary ?? this.summary,
    totalEstimatedCost: totalEstimatedCost ?? this.totalEstimatedCost,
    budgetBreakdown: budgetBreakdown ?? this.budgetBreakdown,
    days: days ?? this.days,
    tips: tips ?? this.tips,
    warnings: warnings ?? this.warnings,
    startDate: startDate ?? this.startDate,
    returnLeg: returnLeg ?? this.returnLeg,
  );
  factory TravelPlan.fromJson(
    Map<String, dynamic> j, {
    int tripId = 0,
    String title = '',
    String startDate = '',
  }) {
    final rawBudget = Map<String, dynamic>.from(
      j['budgetBreakdown'] as Map? ?? {},
    );
    return TravelPlan(
      tripId: tripId,
      title: title,
      // server ส่ง start_date มาข้าง plan_data (GET /trips/:id) — fallback เป็นค่าที่ caller ส่งมา
      startDate: '${j['start_date'] ?? j['startDate'] ?? startDate}',
      summary: '${j['summary'] ?? ''}',
      totalEstimatedCost: _number(j['totalEstimatedCost']),
      budgetBreakdown: rawBudget.map((k, v) => MapEntry(k, _number(v))),
      days: ((j['days'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => TravelDay.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      tips: ((j['tips'] as List?) ?? const []).map((e) => '$e').toList(),
      warnings: ((j['warnings'] as List?) ?? const [])
          .map((e) => '$e')
          .toList(),
      returnLeg: (j['returnLeg'] as Map?) == null
          ? null
          : TravelReturnLeg.fromJson(
              Map<String, dynamic>.from(j['returnLeg'] as Map),
            ),
    );
  }

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'totalEstimatedCost': totalEstimatedCost,
    'budgetBreakdown': budgetBreakdown,
    'days': days.map((e) => e.toJson()).toList(),
    'tips': tips,
    'warnings': warnings,
    if (returnLeg != null) 'returnLeg': returnLeg!.toJson(),
  };

  /// มุมมองแบบแบนสำหรับ Map/Navigation ที่ไม่ต้องสนใจการแบ่งวัน
  List<TravelStop> get allStops => days.expand((d) => d.stops).toList();
}

double _number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

// example.com/.org/.net are documentation-only domains. Older AI plans may
// contain invented URLs on those hosts, so treat them as missing media instead
// of sending a request that is guaranteed to fail.
String _planImageUrl(dynamic value) {
  final url = '${value ?? ''}'.trim();
  if (url.isEmpty) return '';

  final uri = Uri.tryParse(url);
  if (uri == null) return '';

  final host = uri.host.toLowerCase();
  const placeholderDomains = {'example.com', 'example.org', 'example.net'};
  final isPlaceholder = placeholderDomains.any(
    (domain) => host == domain || host.endsWith('.$domain'),
  );
  return isPlaceholder || host.endsWith('.invalid') ? '' : url;
}
