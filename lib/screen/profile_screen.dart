// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:myapp/services/api_service.dart';
import 'package:myapp/screen/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

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
  bool _shareLocation = false;
  String _language = 'TH/EN';
  String _profileImageUrl = '';

  // State for provinces visited
  List<String> _visitedProvinces = [];
  final List<String> _allProvinces = [
    'Bangkok',
    'Chiang Mai',
    'Phuket',
    'Krabi',
    'Chonburi',
    'Surat Thani',
    'Chiang Rai',
    'Ayutthaya',
    'Mae Hong Son',
    'Kanchanaburi',
    'Sukhothai',
    'Nakhon Ratchasima',
    'Nong Khai',
    'Rayong',
    'Trang',
    'Phang Nga',
    'Phetchaburi',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = ApiService.currentUser;
    if (user != null) {
      _username = user['username'] ?? '';
      _shareLocation = !(user['is_private_location'] ?? false);
      _profileImageUrl = user['profile_image_url'] ?? '';

      // Load interests
      if (user['interests'] != null) {
        if (user['interests'] is List) {
          _interests = List<String>.from(user['interests']);
        } else if (user['interests'] is String) {
          // If interests is double-encoded
          try {
            _interests = List<String>.from(user['interests']);
          } catch (_) {}
        }
      }
    }
    _loadVisitedProvinces();
  }

  Future<void> _loadVisitedProvinces() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _visitedProvinces =
          prefs.getStringList('visited_provinces') ?? ['Bangkok', 'Chiang Mai'];
    });
  }

  Future<void> _saveVisitedProvinces(List<String> provinces) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('visited_provinces', provinces);
    setState(() {
      _visitedProvinces = provinces;
    });
  }

  Future<void> _updateProfile({
    String? username,
    List<String>? interests,
    bool? isPrivateLocation,
    String? profileImageUrl,
  }) async {
    setState(() => _isLoading = true);

    final finalUsername = username ?? _username;
    final finalInterests = interests ?? _interests;
    final finalPrivateLocation = isPrivateLocation ?? !_shareLocation;
    final finalProfileImageUrl = profileImageUrl ?? _profileImageUrl;

    final result = await ApiService.updateUserProfile(
      username: finalUsername,
      interests: finalInterests,
      isPrivateLocation: finalPrivateLocation,
      profileImageUrl: finalProfileImageUrl,
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

      final result = await ApiService.uploadProfileImageFile(image.path);

      if (mounted) {
        setState(() => _isLoading = false);
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully!'),
            ),
          );
          setState(() {
            _loadUserData();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to upload image'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error choosing image: $e')));
      }
    }
  }

  void _showUrlInputDialog() {
    final controller = TextEditingController(text: _profileImageUrl);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Profile Image URL'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Enter image URL'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateProfile(profileImageUrl: controller.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showEditProfileImageDialog() {
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
                const Text(
                  'Change Profile Photo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4C025).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.photo_library,
                      color: Color(0xFFF4C025),
                    ),
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage(ImageSource.gallery);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4C025).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Color(0xFFF4C025),
                    ),
                  ),
                  title: const Text(
                    'Take a Photo',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage(ImageSource.camera);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4C025).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.link, color: Color(0xFFF4C025)),
                  ),
                  title: const Text(
                    'Enter Image URL',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
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

  void _showEditUsernameDialog() {
    final controller = TextEditingController(text: _username);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Username'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Enter your username'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (controller.text.trim().isNotEmpty) {
                  _updateProfile(username: controller.text.trim());
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
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
                      selectedColor: const Color(0xFFF4C025).withOpacity(0.25),
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

  void _showVisitedProvincesDialog() {
    List<String> tempVisited = List.from(_visitedProvinces);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Visited Provinces'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _allProvinces.length,
                  itemBuilder: (context, index) {
                    final province = _allProvinces[index];
                    final isVisited = tempVisited.contains(province);
                    return CheckboxListTile(
                      title: Text(province),
                      value: isVisited,
                      activeColor: const Color(0xFFF4C025),
                      onChanged: (checked) {
                        setStateDialog(() {
                          if (checked == true) {
                            tempVisited.add(province);
                          } else {
                            tempVisited.remove(province);
                          }
                        });
                      },
                    );
                  },
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
                    _saveVisitedProvinces(tempVisited);
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
          MaterialPageRoute(builder: (context) => const HomeScreen()),
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
              child: GestureDetector(
                onTap: _showEditProfileImageDialog,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 54,
                        backgroundColor: Colors.grey,
                        backgroundImage: NetworkImage(
                          ApiService.getFullImageUrl(
                                _profileImageUrl,
                              ).isNotEmpty
                              ? ApiService.getFullImageUrl(_profileImageUrl)
                              : ApiService.defaultAvatarUrl,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: brandGold,
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
            ),
            const SizedBox(height: 20),

            // Username & Email
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _username.isNotEmpty ? _username : 'กรุณาตั้งชื่อ',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                  onPressed: _showEditUsernameDialog,
                ),
              ],
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
                              color: brandGold.withOpacity(0.12),
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

            // Provinces Visited Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Provinces Visited',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    TextButton(
                      onPressed: _showVisitedProvincesDialog,
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

                // Progress Bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _visitedProvinces.length / 77,
                          backgroundColor: Colors.grey.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            brandGold,
                          ),
                          minHeight: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_visitedProvinces.length} / 77',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Province tags preview
                _visitedProvinces.isEmpty
                    ? const Text(
                        'Select the provinces you have visited!',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _visitedProvinces.map((prov) {
                          return Chip(
                            label: Text(
                              prov,
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Colors.grey.withOpacity(0.08),
                            padding: EdgeInsets.zero,
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
                  onTap: () {},
                ),

                // Share location toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(
                    Icons.location_on_outlined,
                    color: Colors.black54,
                  ),
                  title: const Text('Share location'),
                  activeColor: brandGold,
                  value: _shareLocation,
                  onChanged: (val) {
                    setState(() {
                      _shareLocation = val;
                    });
                    _updateProfile(isPrivateLocation: !val);
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
                      _language = _language == 'TH/EN' ? 'EN' : 'TH/EN';
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
