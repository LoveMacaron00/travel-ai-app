import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myapp/model/scan_result.dart';
import 'package:myapp/services/api_service.dart';
import 'package:myapp/services/location_service.dart';

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
    final sessionResult = await ApiService.getOrCreateChatSession();
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

    final historyResult = await ApiService.getChatMessages(_sessionId!);
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
      loaded.add(
        const ChatMessage(
          text:
              'Ask me about Thai destinations, opening hours, entrance fees, directions, food, or nearby recommendations.',
          isUser: false,
        ),
      );
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
      _showNotice('AI Guide is still preparing your conversation.');
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
    if (length > 2 * 1024 * 1024) {
      _showNotice('Please choose a photo under 2 MB.');
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
          imageCaption: mode.userCaption,
        ),
      );
      _isSending = true;
      _activeScanMode = mode;
    });
    _scrollToBottom();

    final result = await ApiService.sendChatImage(
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
            text:
                result['message'] ??
                'AI Guide could not analyze this photo. Please try again.',
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

    final result = await ApiService.sendChatMessage(
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
            text:
                (data['answer'] ??
                        'I could not find confirmed travel data yet.')
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
            text:
                result['message'] ??
                'The travel assistant is unavailable right now.',
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
        title: const Text(
          'Thai Go',
          style: TextStyle(
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
              child: const Text(
                'Today',
                style: TextStyle(color: Color(0xFF8D95A3), fontSize: 12),
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

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final alignment = message.isUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final bubbleColor = message.isUser
        ? _ChatbotScreenState.brandGold
        : Colors.white;
    final border = message.isUser
        ? null
        : Border.all(color: const Color(0xFFE8EBF0), width: 1);

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.of(context).size.width *
              (message.scanResult != null || message.imageBytes != null
                  ? 0.86
                  : 0.78),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: message.isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!message.isUser)
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 5),
                  child: Text(
                    'AI Guide',
                    style: TextStyle(color: Color(0xFFE8A900), fontSize: 12),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(18),
                  border: border,
                  boxShadow: message.isUser
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: message.imageBytes != null
                    ? _UserImageMessage(message: message)
                    : message.scanResult != null
                    ? _ScanResultView(result: message.scanResult!)
                    : Text(
                        message.text,
                        style: const TextStyle(
                          color: Color(0xFF202636),
                          fontSize: 15,
                          height: 1.35,
                        ),
                      ),
              ),
              if (message.sources.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...message.sources
                    .take(2)
                    .map((source) => _SourcePill(source: source)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SourcePill extends StatelessWidget {
  final Map<String, dynamic> source;

  const _SourcePill({required this.source});

  @override
  Widget build(BuildContext context) {
    final imageUrl = ApiService.getFullImageUrl(
      source['image_url']?.toString(),
    );

    return Container(
      width: 285,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EBF0)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _sourceIcon(),
                  )
                : _sourceIcon(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (source['name'] ?? 'TAT place').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  [source['province'], source['category']]
                      .where(
                        (value) => value != null && value.toString().isNotEmpty,
                      )
                      .join(' - '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF737B8C),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.map_outlined,
            color: _ChatbotScreenState.brandGold,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _sourceIcon() {
    return Container(
      width: 40,
      height: 40,
      color: const Color(0xFFF2F3F5),
      child: const Icon(
        Icons.place_outlined,
        color: Color(0xFF9098A8),
        size: 20,
      ),
    );
  }
}

class _UserImageMessage extends StatelessWidget {
  final ChatMessage message;

  const _UserImageMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Image.memory(
            message.imageBytes!,
            width: 260,
            height: 175,
            fit: BoxFit.cover,
          ),
        ),
        if (message.imageCaption.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            message.imageCaption,
            style: const TextStyle(
              color: Color(0xFF202636),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _ScanResultView extends StatelessWidget {
  final ScanResult result;

  const _ScanResultView({required this.result});

  IconData get _icon => switch (result.mode) {
    ScanMode.place => Icons.account_balance_outlined,
    ScanMode.sign => Icons.translate_rounded,
    ScanMode.food => Icons.restaurant_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final confidence = (result.confidence * 100).round().clamp(0, 100);
    return SizedBox(
      width: 310,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF5D8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icon,
                  size: 19,
                  color: _ChatbotScreenState.brandGold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: const TextStyle(
                        color: Color(0xFF202636),
                        fontSize: 17,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (result.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        result.subtitle,
                        style: const TextStyle(
                          color: Color(0xFF737B8C),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (result.confidence > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: confidence >= 80
                        ? const Color(0xFFEAF7EF)
                        : const Color(0xFFFFF4DD),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$confidence%',
                    style: TextStyle(
                      color: confidence >= 80
                          ? const Color(0xFF288454)
                          : const Color(0xFFA96C00),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (result.originalText.isNotEmpty ||
              result.translatedText.isNotEmpty) ...[
            const SizedBox(height: 16),
            if (result.originalText.isNotEmpty)
              _ResultSection(title: 'Original Thai', body: result.originalText),
            if (result.translatedText.isNotEmpty)
              _ResultSection(
                title: 'English translation',
                body: result.translatedText,
              ),
          ],
          ...result.sections.map(
            (section) =>
                _ResultSection(title: section.title, body: section.body),
          ),
          if (result.candidates.length > 1) ...[
            const Padding(
              padding: EdgeInsets.only(top: 12, bottom: 7),
              child: Text(
                'Other possibilities',
                style: TextStyle(
                  color: Color(0xFF737B8C),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: result.candidates
                  .skip(1)
                  .take(2)
                  .map(
                    (candidate) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F5F7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${candidate.name} ${(candidate.score * 100).round()}%',
                        style: const TextStyle(
                          color: Color(0xFF5F6878),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (result.confidence > 0 && result.confidence < 0.8)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Not fully certain — try a clearer, closer photo.',
                style: TextStyle(
                  color: Color(0xFFA96C00),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  final String title;
  final String body;

  const _ResultSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: Color(0xFFEDF0F3)),
          const SizedBox(height: 11),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF737B8C),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFF202636),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanModeSheet extends StatelessWidget {
  const _ScanModeSheet();

  IconData _icon(ScanMode mode) => switch (mode) {
    ScanMode.place => Icons.account_balance_outlined,
    ScanMode.sign => Icons.translate_rounded,
    ScanMode.food => Icons.restaurant_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD7DAE0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Scan with AI',
              style: TextStyle(
                color: Color(0xFF202636),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose what you want the guide to understand.',
              style: TextStyle(color: Color(0xFF737B8C), fontSize: 13),
            ),
            const SizedBox(height: 14),
            ...ScanMode.values.map(
              (mode) => InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.pop(context, mode),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF5D8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _icon(mode),
                          color: _ChatbotScreenState.brandGold,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mode.title,
                              style: const TextStyle(
                                color: Color(0xFF202636),
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              mode.description,
                              style: const TextStyle(
                                color: Color(0xFF737B8C),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFFA0A6B1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageSourceSheet extends StatelessWidget {
  final ScanMode mode;

  const _ImageSourceSheet({required this.mode});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD7DAE0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              mode.title,
              style: const TextStyle(
                color: Color(0xFF202636),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _SourceAction(
                    icon: Icons.photo_camera_outlined,
                    label: 'Take photo',
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceAction(
                    icon: Icons.photo_library_outlined,
                    label: 'Photo library',
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
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

class _SourceAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(icon, color: _ChatbotScreenState.brandGold, size: 27),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF202636),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  final ScanMode? mode;

  const _TypingBubble({this.mode});

  @override
  Widget build(BuildContext context) {
    final label = switch (mode) {
      ScanMode.place => 'AI Guide is checking the place and nearby context...',
      ScanMode.sign => 'AI Guide is reading and translating the sign...',
      ScanMode.food => 'AI Guide is identifying the Thai dish...',
      null => 'AI Guide is checking TAT details...',
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 14),
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFF8D95A3), fontSize: 13),
        ),
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onCamera;
  final bool isBusy;

  const _ChatInput({
    required this.controller,
    required this.onSend,
    required this.onCamera,
    required this.isBusy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0F1F4))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Scan with AI',
            onPressed: isBusy ? null : onCamera,
            icon: const Icon(
              Icons.photo_camera_outlined,
              color: _ChatbotScreenState.brandGold,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.only(left: 18),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE1E4EA)),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Ask about Thailand...',
                        hintStyle: TextStyle(
                          color: Color(0xFF858C9B),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                  IconButton(
                    onPressed: onSend,
                    icon: const Icon(
                      Icons.send_rounded,
                      color: Color(0xFF697184),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
