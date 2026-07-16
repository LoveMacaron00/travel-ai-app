import 'package:flutter/material.dart';
import 'package:myapp/services/app_services.dart';

/// ImageProvider สำหรับรูปจาก `/uploads` ที่ต้องส่ง Bearer token
/// รูปภายนอกจะได้ header ว่าง จึงไม่มีการส่ง token ออกนอก API origin
ImageProvider<Object> mediaImageProvider(String url) =>
    NetworkImage(url, headers: AppServices.media.headersFor(url));
