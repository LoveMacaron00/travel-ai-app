import 'package:flutter/material.dart';
import 'package:myapp/l10n/l10n.dart';
import 'package:myapp/services/app_services.dart';
import 'package:myapp/services/image_upload.dart';
import 'package:myapp/widgets/media_image.dart';
import 'package:image_picker/image_picker.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _isLoading = false;
  String _username = '';
  String _profileImageUrl = '';

  static const Color _brandGold = Color(0xFFF4C025);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = AppServices.auth.currentUser;
    if (user != null) {
      setState(() {
        _username = user['username'] ?? '';
        _profileImageUrl = user['profile_image_url'] ?? '';
      });
    }
  }

  Future<void> _updateProfile({
    String? username,
    String? profileImageUrl,
  }) async {
    setState(() => _isLoading = true);

    final finalUsername = username ?? _username;
    final finalProfileImageUrl = profileImageUrl ?? _profileImageUrl;

    final result = await AppServices.auth.updateProfile(
      username: finalUsername,
      interests: List<String>.from(
        AppServices.auth.currentUser?['interests'] ?? [],
      ),
      profileImageUrl: finalProfileImageUrl,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success']) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.savedSuccessfully)));
        _loadUserData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? context.l10n.profileUpdateFailed,
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isLoading = true);

      final result = await AppServices.auth.uploadProfileImage(
        ImageUpload(
          bytes: await image.readAsBytes(),
          filename: image.name,
          mimeType: image.mimeType,
        ),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.profilePhotoUploaded)),
          );
          _loadUserData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? context.l10n.uploadFailed),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorOccurred(e.toString()))),
        );
      }
    }
  }

  void _showUrlInputDialog() {
    final controller = TextEditingController(text: _profileImageUrl);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(context.l10n.editProfileImageUrl),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: context.l10n.imageUrlHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _brandGold),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandGold,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                _updateProfile(profileImageUrl: controller.text.trim());
              },
              child: Text(context.l10n.save),
            ),
          ],
        );
      },
    );
  }

  void _showEditProfileImageBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.changeProfilePhoto,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                _buildBottomSheetTile(
                  icon: Icons.photo_library,
                  label: context.l10n.chooseFromGallery,
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage(ImageSource.gallery);
                  },
                ),
                const Divider(height: 1),
                _buildBottomSheetTile(
                  icon: Icons.camera_alt,
                  label: context.l10n.takePhoto,
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage(ImageSource.camera);
                  },
                ),
                const Divider(height: 1),
                _buildBottomSheetTile(
                  icon: Icons.link,
                  label: context.l10n.enterImageUrl,
                  onTap: () {
                    Navigator.pop(context);
                    _showUrlInputDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _brandGold.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: _brandGold),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }

  void _showEditUsernameDialog() {
    final controller = TextEditingController(text: _username);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(context.l10n.editUsername),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: context.l10n.newUsernameHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _brandGold),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandGold,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                if (controller.text.trim().isNotEmpty) {
                  _updateProfile(username: controller.text.trim());
                }
              },
              child: Text(context.l10n.save),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String userEmail = AppServices.auth.currentUser?['email'] ?? '';
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.accountSettings,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _brandGold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile Photo ──────────────────────────────────
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showEditProfileImageBottomSheet,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 56,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: mediaImageProvider(
                              AppServices.media
                                      .fullUrl(_profileImageUrl)
                                      .isNotEmpty
                                  ? AppServices.media.fullUrl(_profileImageUrl)
                                  : AppServices.media.defaultAvatarUrl,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: const BoxDecoration(
                              color: _brandGold,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _showEditProfileImageBottomSheet,
                    icon: const Icon(Icons.edit, size: 15, color: _brandGold),
                    label: Text(
                      l10n.changeProfilePhoto,
                      style: const TextStyle(
                        color: _brandGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Divider(height: 1),
            const SizedBox(height: 24),

            // ── Account Info ───────────────────────────────────
            Text(
              l10n.accountInformation,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),

            // รายการชื่อผู้ใช้
            _buildSettingsTile(
              icon: Icons.person_outline,
              label: l10n.username,
              value: _username.isNotEmpty ? _username : l10n.notSet,
              onTap: _showEditUsernameDialog,
            ),

            const Divider(height: 1),

            // รายการอีเมล (อ่านอย่างเดียว)
            _buildSettingsTile(
              icon: Icons.email_outlined,
              label: l10n.email,
              value: userEmail.isNotEmpty ? userEmail : '-',
              onTap: null, // ไม่อนุญาตให้แก้ไขอีเมล
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    final bool isEditable = onTap != null;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _brandGold.withValues(alpha: 0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: _brandGold, size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.grey,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: isEditable
          ? const Icon(Icons.chevron_right, color: Colors.grey, size: 20)
          : null,
      onTap: onTap,
    );
  }
}
