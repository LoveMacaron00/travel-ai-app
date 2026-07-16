part of '../chatbot_screen.dart';

// ผลวิเคราะห์ place/sign/food ที่ใช้โครง UI เดียวกัน
class ScanResultView extends StatelessWidget {
  final ScanResult result;

  const ScanResultView({super.key, required this.result});

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
