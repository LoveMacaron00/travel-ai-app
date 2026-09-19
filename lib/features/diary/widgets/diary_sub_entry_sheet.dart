import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myapp/core/widgets/media_image.dart';
import 'package:myapp/l10n/l10n.dart';

const _sheetGold = Color(0xfff4b400);
const _sheetPaleGold = Color(0xffffefbd);
const _sheetBorder = Color(0xffe6e6e6);

class DiarySubEntryResult {
  const DiarySubEntryResult({
    required this.note,
    required this.pickedImages,
    required this.keptExistingImages,
  });

  final String note;
  final List<XFile> pickedImages;
  final List<String> keptExistingImages;
}

Future<DiarySubEntryResult?> showDiarySubEntrySheet({
  required BuildContext context,
  String? initialNote,
  List<String> initialImageUrls = const [],
  bool isEdit = false,
  String checkInTitle = '',
}) {
  return showModalBottomSheet<DiarySubEntryResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _DiarySubEntrySheetContent(
      initialNote: initialNote,
      initialImageUrls: initialImageUrls,
      isEdit: isEdit,
      checkInTitle: checkInTitle,
    ),
  );
}

class _DiarySubEntrySheetContent extends StatefulWidget {
  const _DiarySubEntrySheetContent({
    required this.initialNote,
    required this.initialImageUrls,
    required this.isEdit,
    required this.checkInTitle,
  });

  final String? initialNote;
  final List<String> initialImageUrls;
  final bool isEdit;
  final String checkInTitle;

  @override
  State<_DiarySubEntrySheetContent> createState() =>
      _DiarySubEntrySheetContentState();
}

class _DiarySubEntrySheetContentState
    extends State<_DiarySubEntrySheetContent> {
  late final TextEditingController _noteCtrl;
  final List<XFile> _pickedImages = [];
  late final List<String> _existingImages;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.initialNote ?? '');
    _existingImages = List<String>.from(widget.initialImageUrls);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 84,
        maxWidth: 1600,
      );
      if (!mounted || file == null) return;
      setState(() => _pickedImages.add(file));
    } catch (_) {}
  }

  Future<void> _pickMultipleImages() async {
    try {
      final files = await _picker.pickMultiImage(
        imageQuality: 84,
        maxWidth: 1600,
      );
      if (!mounted || files.isEmpty) return;
      setState(() => _pickedImages.addAll(files));
    } catch (_) {}
  }

  void _submit() {
    final note = _noteCtrl.text.trim();
    if (note.isEmpty && _pickedImages.isEmpty && _existingImages.isEmpty) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(
      context,
      DiarySubEntryResult(
        note: note,
        pickedImages: _pickedImages,
        keptExistingImages: _existingImages,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: _sheetPaleGold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_note,
                    color: _sheetGold,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isEdit
                            ? l10n.editDiaryEntry
                            : l10n.addDiaryEntry,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (widget.checkInTitle.isNotEmpty)
                        Text(
                          widget.checkInTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteCtrl,
              minLines: 3,
              maxLines: 6,
              autofocus: !widget.isEdit,
              decoration: InputDecoration(
                hintText: l10n.writeDiaryHint,
                hintStyle: const TextStyle(
                  color: Colors.black38,
                  fontSize: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _sheetBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _sheetGold, width: 1.8),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 16),
            // Existing images
            if (_existingImages.isNotEmpty || _pickedImages.isNotEmpty) ...[
              SizedBox(
                height: 86,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._existingImages.asMap().entries.map((entry) {
                      final index = entry.key;
                      final url = entry.value;
                      return Container(
                        width: 86,
                        height: 86,
                        margin: const EdgeInsets.only(right: 10),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: mediaNetworkImage(
                                url,
                                width: 86,
                                height: 86,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => setState(
                                  () => _existingImages.removeAt(index),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    ..._pickedImages.asMap().entries.map((entry) {
                      final index = entry.key;
                      final file = entry.value;
                      return Container(
                        width: 86,
                        height: 86,
                        margin: const EdgeInsets.only(right: 10),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: kIsWeb
                                  ? Image.network(
                                      file.path,
                                      width: 86,
                                      height: 86,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(file.path),
                                      width: 86,
                                      height: 86,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => setState(
                                  () => _pickedImages.removeAt(index),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            // Buttons to add photos
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: const BorderSide(color: _sheetBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(
                      Icons.photo_camera_outlined,
                      size: 19,
                      color: _sheetGold,
                    ),
                    label: const Text(
                      'ถ่ายรูป',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickMultipleImages,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: const BorderSide(color: _sheetBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(
                      Icons.photo_library_outlined,
                      size: 19,
                      color: _sheetGold,
                    ),
                    label: const Text(
                      'คลังภาพ',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      l10n.cancel,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _sheetGold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      l10n.save,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
