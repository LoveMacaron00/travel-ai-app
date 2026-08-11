import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myapp/l10n/l10n.dart';
import 'package:myapp/model/scan_result.dart';
import 'package:myapp/services/app_services.dart';
import 'package:myapp/services/image_upload.dart';
import 'package:myapp/services/location_service.dart';
import 'package:myapp/widgets/media_image.dart';

part 'chatbot/chat_message_widgets.dart';
part 'chatbot/scan_result_widgets.dart';
part 'chatbot/scan_sheets.dart';

String _scanModeTitle(BuildContext context, ScanMode mode) => switch (mode) {
  ScanMode.place => context.l10n.scanPlaceTitle,
  ScanMode.sign => context.l10n.scanSignTitle,
  ScanMode.food => context.l10n.scanFoodTitle,
};

String _scanModeDescription(BuildContext context, ScanMode mode) =>
    switch (mode) {
      ScanMode.place => context.l10n.scanPlaceDescription,
      ScanMode.sign => context.l10n.scanSignDescription,
      ScanMode.food => context.l10n.scanFoodDescription,
    };

String _scanModeCaption(BuildContext context, ScanMode mode) => switch (mode) {
  ScanMode.place => context.l10n.scanPlaceCaption,
  ScanMode.sign => context.l10n.scanSignCaption,
  ScanMode.food => context.l10n.scanFoodCaption,
};

class ChatMessage {
  final int? id;
  final int? replyToMessageId;
  final String text;
  final bool isUser;
  final List<Map<String, dynamic>> sources;
  final Uint8List? imageBytes;
  final String imageUrl;
  final String imageCaption;
  final ScanResult? scanResult;
  final bool isEdited;

  const ChatMessage({
    this.id,
    this.replyToMessageId,
    required this.text,
    required this.isUser,
    this.sources = const [],
    this.imageBytes,
    this.imageUrl = '',
    this.imageCaption = '',
    this.scanResult,
    this.isEdited = false,
  });

  ChatMessage copyWith({
    int? id,
    int? replyToMessageId,
    String? text,
    String? imageUrl,
    String? imageCaption,
    bool? isEdited,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      text: text ?? this.text,
      isUser: isUser,
      sources: sources,
      imageBytes: imageBytes,
      imageUrl: imageUrl ?? this.imageUrl,
      imageCaption: imageCaption ?? this.imageCaption,
      scanResult: scanResult,
      isEdited: isEdited ?? this.isEdited,
    );
  }
}

/// Chat เดียวรองรับทั้งข้อความและภาพ โดยใช้ bytes แสดงทันทีระหว่างส่ง
/// และใช้ private image URL เมื่อโหลดข้อความเดิมจาก server
class ChatbotScreen extends StatefulWidget {
  final bool openScannerOnStart;

  const ChatbotScreen({super.key, this.openScannerOnStart = false});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  static const Color brandGold = Color(0xFFF4C025);
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<ChatMessage> _messages = [];
  int? _sessionId;
  bool _isLoadingHistory = true;
  bool _isSending = false;
  ScanMode? _activeScanMode;

  @override
  void initState() {
    super.initState();
    _initializeAndMaybeOpenScanner();
  }

  Future<void> _initializeAndMaybeOpenScanner() async {
    await _initializeChat();
    if (!mounted || !widget.openScannerOnStart || _sessionId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showScanFlow();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    final sessionResult = await AppServices.chat.getOrCreateSession();
    if (!mounted) return;
    if (sessionResult['success'] != true) {
      setState(() => _isLoadingHistory = false);
      return;
    }
    final session = Map<String, dynamic>.from(sessionResult['data']);
    _sessionId = int.tryParse('${session['id']}');
    if (_sessionId == null) {
      setState(() => _isLoadingHistory = false);
      return;
    }

    final historyResult = await AppServices.chat.getMessages(_sessionId!);
    if (!mounted) return;
    final loaded = <ChatMessage>[];
    if (historyResult['success'] == true && historyResult['data'] is List) {
      for (final raw in historyResult['data'] as List) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        loaded.add(
          ChatMessage(
            id: int.tryParse('${item['id'] ?? ''}'),
            replyToMessageId: int.tryParse(
              '${item['reply_to_message_id'] ?? ''}',
            ),
            text: '${item['content'] ?? ''}',
            isUser: item['role'] == 'user',
            imageUrl: AppServices.media.fullUrl(item['image_url']?.toString()),
            imageCaption: '${item['image_caption'] ?? ''}',
            isEdited: item['edited_at'] != null,
          ),
        );
      }
    }
    if (loaded.isEmpty) {
      loaded.add(ChatMessage(text: context.l10n.chatIntro, isUser: false));
    }
    setState(() {
      _messages
        ..clear()
        ..addAll(loaded);
      _isLoadingHistory = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage([String? overrideText]) async {
    final text = (overrideText ?? _controller.text).trim();
    if (text.isEmpty || _isSending || _sessionId == null) return;

    final userMessageIndex = _messages.length;
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _controller.clear();
      _isSending = true;
      _activeScanMode = null;
    });
    _scrollToBottom();

    await _requestAssistantAnswer(text, userMessageIndex);
  }

  Future<void> _showScanFlow() async {
    if (_isSending) return;
    if (_sessionId == null) {
      _showNotice(context.l10n.aiPreparingConversation);
      return;
    }

    final mode = await showModalBottomSheet<ScanMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ScanModeSheet(),
    );
    if (!mounted || mode == null) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImageSourceSheet(mode: mode),
    );
    if (!mounted || source == null) return;
    await _pickAndAnalyzeImage(mode, source);
  }

  Future<void> _pickAndAnalyzeImage(ScanMode mode, ImageSource source) async {
    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 84,
      maxWidth: 1920,
      maxHeight: 1920,
      requestFullMetadata: false,
    );
    if (!mounted || image == null) return;

    final length = await image.length();
    if (!mounted) return;
    if (length > 2 * 1024 * 1024) {
      _showNotice(context.l10n.photoUnderTwoMb);
      return;
    }
    final imageBytes = await image.readAsBytes();

    // รูปที่ถ่ายสดใช้ GPS ปัจจุบันสร้าง Smart Diary อัตโนมัติได้
    // ส่วนรูปจาก Gallery อาจถ่ายคนละเวลา จึงไม่ผูกตำแหน่งปัจจุบันให้
    final shouldAttachCurrentLocation = source == ImageSource.camera;
    var position = shouldAttachCurrentLocation
        ? LocationService.instance.currentPosition
        : null;
    if (shouldAttachCurrentLocation && position == null) {
      position = await LocationService.instance.refresh(
        openSettingsWhenDenied: false,
      );
    }
    if (!mounted) return;

    final userMessageIndex = _messages.length;
    ScanResult? completedScanResult;
    String completedAnswer = '';
    String completedImageUrl = '';
    var scanSucceeded = false;
    setState(() {
      _messages.add(
        ChatMessage(
          text: '',
          isUser: true,
          imageBytes: imageBytes,
          imageCaption: _scanModeCaption(context, mode),
        ),
      );
      _isSending = true;
      _activeScanMode = mode;
    });
    _scrollToBottom();

    final result = await AppServices.chat.sendImage(
      sessionId: _sessionId!,
      image: ImageUpload(
        bytes: imageBytes,
        filename: image.name,
        mimeType: image.mimeType,
      ),
      mode: mode.apiValue,
      latitude: position?.latitude,
      longitude: position?.longitude,
    );
    if (!mounted) return;

    setState(() {
      if (result['success'] == true) {
        scanSucceeded = true;
        final data = Map<String, dynamic>.from(result['data'] ?? {});
        completedAnswer = (data['answer'] ?? '').toString();
        completedImageUrl = (data['image_url'] ?? '').toString();
        final userMessageId = int.tryParse('${data['user_message_id'] ?? ''}');
        if (userMessageIndex < _messages.length) {
          _messages[userMessageIndex] = _messages[userMessageIndex].copyWith(
            id: userMessageId,
            imageUrl: AppServices.media.fullUrl(data['image_url']?.toString()),
          );
        }
        final analysisJson = data['analysis'] is Map
            ? Map<String, dynamic>.from(data['analysis'])
            : <String, dynamic>{};
        completedScanResult = analysisJson.isEmpty
            ? null
            : ScanResult.fromJson(analysisJson);
        _messages.add(
          ChatMessage(
            id: int.tryParse('${data['assistant_message_id'] ?? ''}'),
            replyToMessageId: userMessageId,
            text: completedAnswer,
            isUser: false,
            imageUrl: AppServices.media.fullUrl(
              data['assistant_image_url']?.toString(),
            ),
            scanResult: completedScanResult,
          ),
        );
      } else {
        _messages.add(
          ChatMessage(
            text: result['message'] ?? context.l10n.photoAnalysisFailed,
            isUser: false,
          ),
        );
      }
      _isSending = false;
      _activeScanMode = null;
    });
    if (source == ImageSource.camera && scanSucceeded) {
      final diaryResult =
          completedScanResult ??
          ScanResult(
            mode: mode,
            title: _scanModeTitle(context, mode),
            subtitle: completedAnswer,
            confidence: 0,
            sections: const [],
            candidates: const [],
            originalText: '',
            translatedText: '',
          );
      unawaited(
        AppServices.diaryAutomation
            .recordAiCapture(
              result: diaryResult,
              imageUrl: completedImageUrl,
              position: position,
            )
            .then((saved) {
              if (mounted && saved) {
                _showNotice(context.l10n.diarySavedAutomatically);
              }
            }),
      );
    }
    _scrollToBottom();
  }

  void _showNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _requestAssistantAnswer(
    String text,
    int userMessageIndex,
  ) async {
    if (!_isSending) {
      setState(() => _isSending = true);
    }

    final result = await AppServices.chat.sendMessage(
      sessionId: _sessionId!,
      message: text,
    );

    if (!mounted) return;
    setState(() {
      if (result['success'] == true) {
        final data = Map<String, dynamic>.from(result['data'] ?? {});
        if (userMessageIndex < _messages.length) {
          _messages[userMessageIndex] = _messages[userMessageIndex].copyWith(
            id: int.tryParse('${data['user_message_id'] ?? ''}'),
          );
        }
        final userMessageId = _messages[userMessageIndex].id;
        final rawSources = data['sources'] is List
            ? data['sources'] as List
            : [];
        _messages.add(
          ChatMessage(
            id: int.tryParse('${data['assistant_message_id'] ?? ''}'),
            replyToMessageId: userMessageId,
            text: (data['answer'] ?? context.l10n.noConfirmedTravelData)
                .toString(),
            isUser: false,
            sources: rawSources
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(),
          ),
        );
      } else {
        _messages.add(
          ChatMessage(
            text: result['message'] ?? context.l10n.travelAssistantUnavailable,
            isUser: false,
          ),
        );
      }
      _isSending = false;
    });
    _scrollToBottom();
  }

  Future<void> _editMessage(ChatMessage message) async {
    if (_isSending || message.id == null) return;
    final editor = TextEditingController(text: message.text);
    final updatedText = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.chatEditMessage),
        content: TextField(
          controller: editor,
          autofocus: true,
          maxLength: 2000,
          minLines: 1,
          maxLines: 5,
          decoration: InputDecoration(hintText: context.l10n.askThailandHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final value = editor.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    editor.dispose();
    if (!mounted || updatedText == null) return;

    setState(() {
      _isSending = true;
      _activeScanMode = null;
    });
    final result = await AppServices.chat.updateMessage(
      messageId: message.id!,
      message: updatedText,
    );
    if (!mounted) return;
    if (result['success'] != true) {
      setState(() => _isSending = false);
      _showNotice(result['message'] ?? context.l10n.chatEditFailed);
      return;
    }

    final data = Map<String, dynamic>.from(result['data'] ?? {});
    final deletedAssistantIds = data['deleted_assistant_message_ids'] is List
        ? (data['deleted_assistant_message_ids'] as List)
              .map((id) => int.tryParse('$id'))
              .whereType<int>()
              .toSet()
        : <int>{};
    final index = _messages.indexWhere((item) => item.id == message.id);
    if (index < 0) {
      setState(() => _isSending = false);
      return;
    }
    setState(() {
      _messages[index] = _messages[index].copyWith(
        text: updatedText,
        isEdited: true,
      );
      _messages.removeWhere(
        (item) =>
            deletedAssistantIds.contains(item.id) ||
            item.replyToMessageId == message.id,
      );

      final updatedUserIndex = _messages.indexWhere(
        (item) => item.id == message.id,
      );
      final rawSources = data['sources'] is List ? data['sources'] as List : [];
      _messages.insert(
        updatedUserIndex + 1,
        ChatMessage(
          id: int.tryParse('${data['assistant_message_id'] ?? ''}'),
          replyToMessageId: message.id,
          text: (data['answer'] ?? context.l10n.noConfirmedTravelData)
              .toString(),
          isUser: false,
          sources: rawSources
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(),
        ),
      );
      _isSending = false;
    });
    _scrollToBottom();
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    if (_isSending || message.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.chatDeleteMessage),
        content: Text(context.l10n.chatDeleteConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              context.l10n.chatDeleteMessage,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    final result = await AppServices.chat.deleteMessage(message.id!);
    if (!mounted) return;
    if (result['success'] != true) {
      _showNotice(result['message'] ?? context.l10n.chatDeleteFailed);
      return;
    }
    final data = result['data'] is Map
        ? Map<String, dynamic>.from(result['data'])
        : <String, dynamic>{};
    final deletedIds = data['deleted_message_ids'] is List
        ? (data['deleted_message_ids'] as List)
              .map((id) => int.tryParse('$id'))
              .whereType<int>()
              .toSet()
        : <int>{message.id!};
    setState(() {
      _messages.removeWhere(
        (item) =>
            deletedIds.contains(item.id) || item.replyToMessageId == message.id,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.l10n.appTitle,
          style: const TextStyle(
            color: Color(0xFFE8A900),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                context.l10n.today,
                style: const TextStyle(color: Color(0xFF8D95A3), fontSize: 12),
              ),
            ),
            Expanded(
              child: _isLoadingHistory
                  ? const Center(
                      child: CircularProgressIndicator(color: brandGold),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                      itemCount: _messages.length + (_isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isSending && index == _messages.length) {
                          return _TypingBubble(mode: _activeScanMode);
                        }
                        final message = _messages[index];
                        final hasImage =
                            message.imageBytes != null ||
                            message.imageUrl.isNotEmpty;
                        return _ChatBubble(
                          message: message,
                          onEdit:
                              message.isUser && message.id != null && !hasImage
                              ? () => _editMessage(message)
                              : null,
                          onDelete: message.isUser && message.id != null
                              ? () => _deleteMessage(message)
                              : null,
                        );
                      },
                    ),
            ),
            _ChatInput(
              controller: _controller,
              onSend: _sendMessage,
              onCamera: _showScanFlow,
              isBusy: _isSending,
            ),
          ],
        ),
      ),
    );
  }
}
