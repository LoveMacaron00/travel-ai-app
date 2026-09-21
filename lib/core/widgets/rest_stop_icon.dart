import 'package:flutter/material.dart';

/// ไอคอนตามประเภทจุดแวะพัก OSM — ใช้ร่วมกันทั้งหน้าแผน/นำทาง
/// (รวม `_restStopIcon` ที่เคยนิยามซ้ำกันใน plan_details กับ plan_navigation_screen)
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
