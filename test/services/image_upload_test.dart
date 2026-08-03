import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/services/image_upload.dart';

void main() {
  test('creates a web-safe multipart image from bytes', () async {
    final upload = ImageUpload(
      bytes: Uint8List.fromList([1, 2, 3]),
      filename: r'C:\fakepath\photo.jpg',
      mimeType: 'image/jpg',
    );

    final multipart = upload.asMultipartFile('image');

    expect(multipart.field, 'image');
    expect(multipart.filename, 'photo.jpg');
    expect(multipart.contentType.mimeType, 'image/jpeg');
    expect(await multipart.finalize().toBytes(), [1, 2, 3]);
  });

  test('infers MIME type from the filename when the browser omits it', () {
    final upload = ImageUpload(bytes: Uint8List(0), filename: 'scan.webp');

    expect(upload.asMultipartFile('image').contentType.mimeType, 'image/webp');
  });
}
