import 'package:flutter/material.dart';

/// ใช้เส้นทางถนนจริง (OSRM) หรือเส้นตรงจุดถึงจุด — กติกาเดียวทั้งหน้าแผน/นำทาง
/// (รวม `_usesRoadRoute` ที่เคยนิยามซ้ำกันใน plan_components กับ plan_navigation_screen)
bool usesRoadRoute(String mode) =>
    const {'car', 'walking', 'bus', 'bicycle', 'cycling'}.contains(
      mode.toLowerCase(),
    );

/// สีเส้นนำทาง — สีฟ้าอ่อนทุกพาหนะ (0xff42a5f5)
/// (เดิมให้สีตามพาหนะ: รถ=ทอง เดิน=เทา ฯลฯ — เปลี่ยนตามดีไซน์ให้เป็นฟ้าเส้นเดียว)
/// รับ fallback เป็น param คงไว้เพื่อไม่ต้องแก้ caller (หน้าแผน/หน้านำทาง/ชิปขาเดินทาง)
Color routeLineColor(
  String mode, {
  Color fallback = const Color(0xff42a5f5),
}) => const Color(0xff42a5f5);

/// สีพื้นชิปขาเดินทาง — สีเดิมตามพาหนะ (รถ=ทอง เดิน=เทา ฯลฯ)
/// แยกจากสีเส้นบนแผนที่ซึ่งเป็นฟ้าเส้นเดียวแล้ว
Color routeChipColor(
  String mode, {
  Color fallback = const Color(0xffe9ad0c),
}) => switch (mode.toLowerCase()) {
  'walking' => const Color(0xff6d7278),
  'bus' => const Color(0xff2d7dd2),
  'train' => const Color(0xff7b2cbf),
  'ferry' => const Color(0xff0096c7),
  'flight' => const Color(0xffe76f51),
  'bicycle' || 'bike' || 'cycling' => const Color(0xff2e9e62),
  _ => fallback,
};

/// สีตัวอักษรป้ายขาเดินทาง (ใช้เฉพาะหน้าแผน)
Color routeLabelColor(String mode) => switch (mode.toLowerCase()) {
  'walking' => const Color(0xff4f5459),
  'bus' => const Color(0xff1f5f9f),
  'train' => const Color(0xff61208f),
  'ferry' => const Color(0xff00779e),
  'flight' => const Color(0xffb84d36),
  'bicycle' || 'bike' || 'cycling' => const Color(0xff1e7a4c),
  _ => const Color(0xff7a5800),
};
