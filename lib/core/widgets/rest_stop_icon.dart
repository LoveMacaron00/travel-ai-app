import 'package:flutter/material.dart';

/// ไอคอนตามประเภทจุด transfer (เช่น สนามบิน) — ใช้ในหน้านำทาง
IconData restStopIcon(String restType) => switch (restType.toLowerCase()) {
  'fuel' => Icons.local_gas_station,
  'cafe' => Icons.local_cafe,
  'restaurant' => Icons.restaurant,
  'hotel' => Icons.hotel,
  'parking' => Icons.local_parking,
  'toilets' => Icons.wc,
  'rest_area' => Icons.landscape,
  'airport' => Icons.flight,
  _ => Icons.store,
};
