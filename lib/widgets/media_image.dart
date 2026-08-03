import 'package:flutter/material.dart';
import 'package:myapp/services/app_services.dart';

/// ImageProvider สำหรับรูปจาก `/uploads` ที่ต้องส่ง Bearer token
/// รูปภายนอกจะได้ header ว่าง จึงไม่มีการส่ง token ออกนอก API origin
ImageProvider<Object> mediaImageProvider(String url) {
  final resolved = AppServices.media.fullUrl(url);
  return NetworkImage(
    resolved,
    headers: AppServices.media.headersFor(resolved),
  );
}

/// Image.network กลางที่ resolve private media และ Web media proxy เหมือนกัน
/// ทุกหน้าจอ เพื่อไม่ให้บาง flow กลับไปชน CORS ของ CDN โดยตรง
Widget mediaNetworkImage(
  String url, {
  double? width,
  double? height,
  BoxFit? fit,
  ImageErrorWidgetBuilder? errorBuilder,
}) {
  final resolved = AppServices.media.fullUrl(url);
  return Image.network(
    resolved,
    headers: AppServices.media.headersFor(resolved),
    width: width,
    height: height,
    fit: fit,
    errorBuilder: errorBuilder,
  );
}
