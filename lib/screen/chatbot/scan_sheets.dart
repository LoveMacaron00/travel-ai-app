part of '../chatbot_screen.dart';

// Bottom sheets และ input controls ของ image scan/chat
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
