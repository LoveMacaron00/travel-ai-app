import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:myapp/services/api_service.dart';
import 'package:myapp/screen/welcome_screen.dart';
import 'package:myapp/screen/account_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onBackTap;

  const ProfileScreen({super.key, required this.onBackTap});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  String _username = '';
  List<String> _interests = [];
  String _language = 'TH';
  String _profileImageUrl = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = ApiService.currentUser;
    if (user != null) {
      _username = user['username'] ?? '';
      _profileImageUrl = user['profile_image_url'] ?? '';

      // Load interests
      if (user['interests'] != null) {
        if (user['interests'] is List) {
          _interests = List<String>.from(user['interests']);
        } else if (user['interests'] is String) {
          // รองรับข้อมูลเก่าที่ backend เคยเก็บ array เป็น JSON string
          try {
            final decoded = jsonDecode(user['interests']);
            if (decoded is List) _interests = List<String>.from(decoded);
          } on FormatException {
            _interests = const [];
          }
        }
      }
    }
  }

  Future<void> _updateProfile({List<String>? interests}) async {
    setState(() => _isLoading = true);

    final finalInterests = interests ?? _interests;

    final result = await ApiService.updateUserProfile(
      username: _username,
      interests: finalInterests,
      profileImageUrl: _profileImageUrl,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        setState(() {
          _loadUserData();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to update profile'),
          ),
        );
      }
    }
  }

  void _showEditInterestsDialog() {
    final List<String> availableInterests = [
      'Food',
      'Cafe',
      'Nature',
      'Beach',
      'Temple',
      'Adventure',
      'Shopping',
      'Nightlife',
      'Culture',
    ];
    List<String> tempSelected = List.from(_interests);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Edit Interests'),
              content: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableInterests.map((interest) {
                    final isSelected = tempSelected.contains(interest);
                    return FilterChip(
                      label: Text(interest),
                      selected: isSelected,
                      selectedColor: const Color(
                        0xFFF4C025,
                      ).withValues(alpha: 0.25),
                      checkmarkColor: const Color(0xFFF4C025),
                      onSelected: (selected) {
                        setStateDialog(() {
                          if (selected) {
                            tempSelected.add(interest);
                          } else {
                            tempSelected.remove(interest);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateProfile(interests: tempSelected);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out of Go Thai?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await ApiService.clearSession();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandGold = Color(0xFFF4C025);
    final String userEmail = ApiService.currentUser?['email'] ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: widget.onBackTap,
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
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
                    color: brandGold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // User Avatar Section
            Center(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 54,
                  backgroundColor: Colors.grey,
                  backgroundImage: NetworkImage(
                    ApiService.getFullImageUrl(_profileImageUrl).isNotEmpty
                        ? ApiService.getFullImageUrl(_profileImageUrl)
                        : ApiService.defaultAvatarUrl,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Username & Email
            Text(
              _username.isNotEmpty ? _username : 'กรุณาตั้งชื่อ',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              userEmail,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 30),

            // Interests Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'My Interests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    TextButton(
                      onPressed: _showEditInterestsDialog,
                      child: const Text(
                        'Edit',
                        style: TextStyle(
                          color: brandGold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _interests.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'No interests added yet. Click edit to customize!',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _interests.map((interest) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: brandGold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              interest,
                              style: const TextStyle(
                                color: brandGold,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ],
            ),
            const Divider(height: 40, thickness: 1),

            // Settings Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),

                // Account settings tile
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.manage_accounts_outlined,
                    color: Colors.black54,
                  ),
                  title: const Text('Account Settings'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AccountSettingsScreen(),
                      ),
                    );
                    // Refresh profile data when returning from Account Settings
                    setState(() => _loadUserData());
                  },
                ),

                // Language selection
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.translate_outlined,
                    color: Colors.black54,
                  ),
                  title: const Text('Language'),
                  trailing: Text(
                    _language,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _language = _language == 'TH' ? 'EN' : 'TH';
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Log Out Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandGold,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _handleLogout,
                child: const Text('Log Out'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
