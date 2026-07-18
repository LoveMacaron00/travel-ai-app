import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myapp/l10n/l10n.dart';
import 'package:myapp/model/scan_result.dart';
import 'package:myapp/services/app_services.dart';
import 'package:myapp/services/location_service.dart';

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
  final String text;
  final bool isUser;
  final List<Map<String, dynamic>> sources;
  final Uint8List? imageBytes;
  final String imageCaption;
  final ScanResult? scanResult;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.sources = const [],
    this.imageBytes,
    this.imageCaption = '',
    this.scanResult,
  });
}

/// Chat เดียวรองรับทั้งข้อความและภาพ โดยภาพจะถูกส่งแบบ in-memory ไปยัง server
/// และไม่ถูกบันทึกเป็นไฟล์ต้นฉบับบน server
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
            text: '${item['content'] ?? ''}',
            isUser: item['role'] == 'user',
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

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _controller.clear();
      _isSending = true;
      _activeScanMode = null;
    });
    _scrollToBottom();

    await _requestAssistantAnswer(text);
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

    var position = LocationService.instance.currentPosition;
    if (mode == ScanMode.place && position == null) {
      position = await LocationService.instance.refresh(
        openSettingsWhenDenied: false,
      );
    }
    if (!mounted) return;

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
      filePath: image.path,
      mode: mode.apiValue,
      latitude: position?.latitude,
      longitude: position?.longitude,
    );
    if (!mounted) return;

    setState(() {
      if (result['success'] == true) {
        final data = Map<String, dynamic>.from(result['data'] ?? {});
        final analysisJson = data['analysis'] is Map
            ? Map<String, dynamic>.from(data['analysis'])
            : <String, dynamic>{};
        _messages.add(
          ChatMessage(
            text: (data['answer'] ?? '').toString(),
            isUser: false,
            scanResult: analysisJson.isEmpty
                ? null
                : ScanResult.fromJson(analysisJson),
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
    _scrollToBottom();
  }

  void _showNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _requestAssistantAnswer(String text) async {
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
        final rawSources = data['sources'] is List
            ? data['sources'] as List
            : [];
        _messages.add(
          ChatMessage(
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
                        return _ChatBubble(message: _messages[index]);
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
