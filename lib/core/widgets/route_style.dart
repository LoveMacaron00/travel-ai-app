import 'package:flutter/material.dart';

/// ใช้เส้นทางถนนจริง (OSRM) หรือเส้นตรงจุดถึงจุด — กติกาเดียวทั้งหน้าแผน/นำทาง
/// (รวม `_usesRoadRoute` ที่เคยนิยามซ้ำกันใน plan_components กับ plan_navigation_screen)
bool usesRoadRoute(String mode) =>
    const {'car', 'walking', 'bus', 'bicycle', 'cycling'}.contains(
      mode.toLowerCase(),
    );

/// สีเส้นตามพาหนะ — หน้าแผนกับหน้านำทางเคยนิยามซ้ำกัน ต่างกันแค่สี fallback
/// จึงรับ fallback เป็น param เพื่อให้พิกเซลเหมือนเดิมทุกประการ
/// (หน้าแผน: ทอง `_gold` 0xffe9ad0c / หน้านำทาง: 0xffe8ad10)
Color routeLineColor(
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
