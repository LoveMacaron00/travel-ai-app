part of '../chatbot_screen.dart';

// Bubble ของข้อความ ผู้ใช้ และแหล่งอ้างอิง
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ChatBubble({required this.message, this.onEdit, this.onDelete});

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
              (message.scanResult != null ||
                      message.imageBytes != null ||
                      message.imageUrl.isNotEmpty
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
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 5),
                  child: Text(
                    context.l10n.aiGuide,
                    style: const TextStyle(
                      color: Color(0xFFE8A900),
                      fontSize: 12,
                    ),
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
                child: message.imageBytes != null || message.imageUrl.isNotEmpty
                    ? _ImageMessage(message: message)
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
              if (message.isUser && (onEdit != null || onDelete != null))
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.isEdited)
                      Text(
                        context.l10n.chatEdited,
                        style: const TextStyle(
                          color: Color(0xFF8D95A3),
                          fontSize: 11,
                        ),
                      ),
                    PopupMenuButton<String>(
                      tooltip: context.l10n.chatMessageOptions,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 30,
                        minHeight: 28,
                      ),
                      icon: const Icon(
                        Icons.more_horiz,
                        size: 18,
                        color: Color(0xFF8D95A3),
                      ),
                      onSelected: (action) {
                        if (action == 'edit') onEdit?.call();
                        if (action == 'delete') onDelete?.call();
                      },
                      itemBuilder: (context) => [
                        if (onEdit != null)
                          PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.edit_outlined),
                              title: Text(context.l10n.chatEditMessage),
                            ),
                          ),
                        if (onDelete != null)
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              title: Text(
                                context.l10n.chatDeleteMessage,
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
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
                ? mediaNetworkImage(
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
                  (source['name'] ?? context.l10n.tatPlace).toString(),
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

class _ImageMessage extends StatelessWidget {
  final ChatMessage message;

  const _ImageMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final imageUrl = AppServices.media.fullUrl(message.imageUrl);
    final image = message.imageBytes != null
        ? Image.memory(
            message.imageBytes!,
            width: 260,
            height: 175,
            fit: BoxFit.cover,
          )
        : mediaNetworkImage(
            imageUrl,
            width: 260,
            height: 175,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 260,
              height: 175,
              color: const Color(0xFFF2F3F5),
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image_outlined,
                color: Color(0xFF9098A8),
              ),
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(13), child: image),
        if (message.scanResult != null) ...[
          const SizedBox(height: 10),
          ScanResultView(result: message.scanResult!),
        ] else if (message.text.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            message.text,
            style: const TextStyle(
              color: Color(0xFF202636),
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ] else if (message.imageCaption.isNotEmpty) ...[
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
