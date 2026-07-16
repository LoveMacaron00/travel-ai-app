part of '../chatbot_screen.dart';

// Bubble ของข้อความ ผู้ใช้ และแหล่งอ้างอิง
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
                    ? ScanResultView(result: message.scanResult!)
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
    final imageUrl = AppServices.media.fullUrl(source['image_url']?.toString());

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
                    headers: AppServices.media.headersFor(imageUrl),
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
