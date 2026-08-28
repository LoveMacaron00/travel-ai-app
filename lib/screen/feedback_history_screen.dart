import 'package:flutter/material.dart';
import 'package:myapp/l10n/l10n.dart';
import 'package:myapp/services/app_services.dart';

class FeedbackHistoryScreen extends StatefulWidget {
  const FeedbackHistoryScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<FeedbackHistoryScreen> createState() => _FeedbackHistoryScreenState();
}

class _FeedbackHistoryScreenState extends State<FeedbackHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _feedbackList = [];
  static const Color _brandGold = Color(0xFFF4C025);

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  Future<void> _loadFeedback() async {
    setState(() => _isLoading = true);
    
    final result = await AppServices.feedback.getUserFeedback();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _feedbackList = List<Map<String, dynamic>>.from(result['data'] ?? []);
        }
      });
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _showFeedbackDialog() async {
    final feedbackController = TextEditingController();
    final isSubmitting = ValueNotifier<bool>(false);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.sendFeedback),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: feedbackController,
                maxLines: 5,
                minLines: 3,
                decoration: InputDecoration(
                  hintText: context.l10n.feedbackHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.cancel),
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
                              SnackBar(content: Text(context.l10n.feedbackRequired)),
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
                                  content: Text(
                                    result['message'] ?? context.l10n.feedbackFailed,
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.l10n.send),
                );
              },
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.feedbackSuccess)),
      );
      _loadFeedback();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: widget.onBack ?? () => Navigator.maybePop(context),
        ),
        title: Text(
          l10n.sendFeedback,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _brandGold,
        onPressed: _showFeedbackDialog,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _brandGold),
            )
          : _feedbackList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.feedback_outlined,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No feedback yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _feedbackList.length,
                  itemBuilder: (context, index) {
                    final feedback = _feedbackList[index];
                    return _buildFeedbackCard(feedback);
                  },
                ),
    );
  }

  Widget _buildFeedbackCard(Map<String, dynamic> feedback) {
    final message = feedback['message'] ?? '';
    final adminReply = feedback['admin_reply'];
    final status = '${feedback['status'] ?? 'pending'}';
    final createdAt = feedback['created_at'] ?? '';
    final isReplied = status == 'replied' ||
        status == 'resolved' ||
        (adminReply != null && adminReply.toString().isNotEmpty);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isReplied
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isReplied ? 'Replied' : 'Pending',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isReplied
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // User message
            Text(
              'Your feedback:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            
            // Admin reply (if exists)
            if (adminReply != null && adminReply.toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _brandGold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin reply:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _brandGold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      adminReply.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}