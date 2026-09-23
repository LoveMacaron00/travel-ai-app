class PlaceMarker {
  final String id;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final String category;
  final String province;

  /// เวลาเปิด-ปิดจาก DB ("08:00"/"18:00") — '' คือไม่ระบุ
  /// ใช้ตรวจว่า must-visit ที่ผู้ใช้เพิ่มเองเกินเวลาทำการไหม (ชิป "อาจปิดแล้ว")
  final String openingTime;
  final String closingTime;

  PlaceMarker({
    required this.id,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    required this.category,
    this.province = '',
    this.openingTime = '',
    this.closingTime = '',
  });
}
