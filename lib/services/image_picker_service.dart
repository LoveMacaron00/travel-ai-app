import 'package:image_picker/image_picker.dart';
import 'package:myapp/services/image_upload.dart';

/// Centralized image picking — previously duplicated in 4 places:
/// `account_settings_screen.dart:77`, `chatbot_screen.dart:103`,
/// `travel_diary_screen.dart:147` + `travel_diary_screen.dart:508`
/// All used `ImagePicker().pickImage(...)` + `XFile.readAsBytes()` + `ImageUpload`.
/// This service keeps behavior identical but removes duplication.
class ImagePickerService {
  const ImagePickerService._();

  static final ImagePicker _picker = ImagePicker();

  /// Picks an image and converts to [ImageUpload] for upload services.
  /// Returns null if user cancels.
  /// Keeps original `imageQuality` / `maxWidth` defaults used in screens.
  static Future<ImageUpload?> pickImage({
    required ImageSource source,
    int imageQuality = 84,
    double? maxWidth = 1600,
  }) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: imageQuality,
      maxWidth: maxWidth,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return ImageUpload(
      bytes: bytes,
      filename: file.name,
      mimeType: file.mimeType,
    );
  }

  /// Picks directly as [ImageUpload] with chat-style limits (1920, 84, 2MB guard handled by caller)
  static Future<XFile?> pickRawImage({
    required ImageSource source,
    int imageQuality = 84,
    double? maxWidth = 1920,
  }) =>
      _picker.pickImage(
        source: source,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
      );
}
