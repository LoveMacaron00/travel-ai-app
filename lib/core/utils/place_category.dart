import 'package:flutter/material.dart';
import 'package:myapp/l10n/app_localizations.dart';

/// หมวดหมู่ตัวกรองที่ใช้ร่วมกันทั้งแอป (แผนที่ / เลือกสถานที่ / ดูสถานที่ทั้งหมด)
///
/// - 'accommodation' ควบ 'hotel' (sync เขียน hotel, admin เพิ่มเองใช้ accommodation)
/// - 'other' ควบ service/activity/general
const placeCategoryFilters = [
  'all',
  'attraction',
  'accommodation',
  'restaurant',
  'shop',
  'other',
];

/// เทียบหมวดหมู่ของสถานที่กับตัวกรองที่เลือก (รวม alias ข้างบน)
bool matchesPlaceCategory(String placeCategory, String selected) {
  final selectedKey = selected.toLowerCase();
  if (selectedKey == 'all') return true;
  final category = placeCategory.toLowerCase();
  if (selectedKey == 'accommodation') {
    return category == 'accommodation' || category == 'hotel';
  }
  if (selectedKey == 'other') {
    return category == 'other' ||
        category == 'service' ||
        category == 'activity' ||
        category == 'general';
  }
  return category == selectedKey;
}

/// หมวดหมู่ว่าง ('') ถือเป็น other — ตรงกับ default 'other' ของ map/plan
String normalizePlaceCategory(String? category) {
  final value = (category ?? '').trim();
  return value.isEmpty ? 'other' : value;
}

String placeCategoryLabel(AppLocalizations l10n, String category) {
  switch (category.toLowerCase()) {
    case 'all':
      return l10n.categoryAll;
    case 'attraction':
      return l10n.categoryAttraction;
    case 'accommodation':
    case 'hotel':
      return l10n.categoryAccommodation;
    case 'restaurant':
      return l10n.categoryRestaurant;
    case 'shop':
      return l10n.categoryShop;
    case 'other':
      return l10n.categoryOther;
    default:
      return category;
  }
}

Color placeCategoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'all':
      return Colors.grey.shade700;
    case 'attraction':
      return Colors.redAccent;
    case 'accommodation':
    case 'hotel':
      return Colors.blueAccent;
    case 'restaurant':
      return Colors.orange;
    case 'shop':
      return Colors.green;
    case 'other':
      return Colors.purple;
    default:
      return Colors.grey;
  }
}

IconData placeCategoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'all':
      return Icons.apps;
    case 'attraction':
      return Icons.attractions;
    case 'accommodation':
    case 'hotel':
      return Icons.hotel;
    case 'restaurant':
      return Icons.restaurant;
    case 'shop':
      return Icons.shopping_bag;
    case 'other':
      return Icons.category;
    default:
      return Icons.place;
  }
}
