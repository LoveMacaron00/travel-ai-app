import 'package:flutter/material.dart';
import 'package:myapp/l10n/l10n.dart';
import 'package:myapp/services/app_services.dart';

/// Centralized feedback dialog — previously duplicated in:
/// `profile_screen.dart:292 _showFeedbackDialog` and
/// `feedback_history_screen.dart:49 _showFeedbackDialog`
/// Both had identical AlertDialog + TextField + ValueNotifier isSubmitting + submit logic.
/// This keeps behavior identical but single source.
Future<bool?> showFeedbackDialog(BuildContext context) {
  final feedbackController = TextEditingController();
  final isSubmitting = ValueNotifier<bool>(false);

  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(dialogContext.l10n.sendFeedback),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: feedbackController,
              maxLines: 5,
              minLines: 3,
              decoration: InputDecoration(
                hintText: dialogContext.l10n.feedbackHint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: isSubmitting,
            builder: (context, submitting, child) {
              return ElevatedButton(
                onPressed: submitting
                    ? null
                    : () async {
                        if (feedbackController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text(dialogContext.l10n.feedbackRequired)),
                          );
                          return;
                        }
                        isSubmitting.value = true;
                        final result = await AppServices.feedback.submitFeedback(
                          message: feedbackController.text.trim(),
                        );
                        if (dialogContext.mounted) {
                          isSubmitting.value = false;
                          if (result['success'] == true) {
                            Navigator.pop(dialogContext, true);
                          } else {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(result['message'] ?? dialogContext.l10n.feedbackFailed),
                              ),
                            );
                          }
                        }
                      },
                child: submitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(dialogContext.l10n.send),
              );
            },
          ),
        ],
      );
    },
  );
}
