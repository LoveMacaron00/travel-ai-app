// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:myapp/services/api_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final List<Map<String, dynamic>> sources;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.sources = const [],
  });
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  static const Color brandGold = Color(0xFFF4C025);
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  int? _sessionId;
  bool _isLoadingHistory = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
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
    });
    _scrollToBottom();

    await _requestAssistantAnswer(text);
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
                          return const _TypingBubble();
                        }
                        return _ChatBubble(message: _messages[index]);
                      },
                    ),
            ),
            _ChatInput(controller: _controller, onSend: _sendMessage),
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
          maxWidth: MediaQuery.of(context).size.width * 0.78,
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
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(18),
                  border: border,
                  boxShadow: message.isUser
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: Text(
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

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(left: 4, bottom: 14),
        child: Text(
          'AI Guide is checking TAT details...',
          style: TextStyle(color: Color(0xFF8D95A3), fontSize: 13),
        ),
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _ChatInput({required this.controller, required this.onSend});

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
