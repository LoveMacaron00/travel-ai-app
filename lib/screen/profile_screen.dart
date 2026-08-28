import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/l10n/l10n.dart';
import 'package:myapp/services/app_services.dart';
import 'package:myapp/services/travel_diary_automation_service.dart';
import 'package:myapp/widgets/media_image.dart';
import 'package:myapp/screen/welcome_screen.dart';
import 'package:myapp/screen/account_settings_screen.dart';
import 'package:myapp/screen/travel_footprint_screen.dart';
import 'package:myapp/screen/plan_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onBackTap;
  final void Function(int tripId)? onViewPlan;

  const ProfileScreen({super.key, required this.onBackTap, this.onViewPlan});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  String _username = '';
  List<String> _interests = [];
  String _profileImageUrl = '';
  
  bool _loadingPlans = false;
  List<Map<String, dynamic>> _savedPlans = [];
  bool _autoDiaryEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSavedPlans();
    TravelDiaryAutomationService.isEnabled().then((enabled) {
      if (mounted) setState(() => _autoDiaryEnabled = enabled);
    });
  }

  Future<void> _loadSavedPlans() async {
    if (mounted) setState(() => _loadingPlans = true);
    final result = await AppServices.trips.listMyPlans();
    if (!mounted) return;
    
    if (result['success'] == true) {
      final allPlans = List<Map<String, dynamic>>.from(result['data'] ?? []);
      // Filter out trips that don't have plan_data (e.g. generation failed or incomplete)
      setState(() {
        _savedPlans = allPlans.where((plan) => plan['plan_data'] != null).toList();
        _loadingPlans = false;
      });
    } else {
      setState(() => _loadingPlans = false);
    }
  }

  void _loadUserData() {
    final user = AppServices.auth.currentUser;
    if (user != null) {
      _username = user['username'] ?? '';
      _profileImageUrl = user['profile_image_url'] ?? '';

      // โหลดความสนใจ
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

    final result = await AppServices.auth.updateProfile(
      username: _username,
      interests: finalInterests,
      profileImageUrl: _profileImageUrl,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success']) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.profileUpdated)));
        setState(() {
          _loadUserData();
        });
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

  void _showEditInterestsDialog() {
    const availableInterests = <String>[
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
              title: Text(context.l10n.editInterests),
              content: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableInterests.map((interest) {
                    final isSelected = tempSelected.contains(interest);
                    return FilterChip(
                      label: Text(_interestLabel(context, interest)),
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
                  child: Text(context.l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateProfile(interests: tempSelected);
                  },
                  child: Text(context.l10n.save),
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
          title: Text(context.l10n.logOut),
          content: Text(context.l10n.logOutConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(context.l10n.logOut),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await AppServices.activity.pause();
      await AppServices.auth.clearSession();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }
    }
  }

  String _interestLabel(BuildContext context, String interest) {
    final l10n = context.l10n;
    return switch (interest) {
      'Food' => l10n.interestFood,
      'Cafe' => l10n.interestCafe,
      'Nature' => l10n.interestNature,
      'Beach' => l10n.interestBeach,
      'Temple' => l10n.interestTemple,
      'Adventure' => l10n.interestAdventure,
      'Shopping' => l10n.interestShopping,
      'Nightlife' => l10n.interestNightlife,
      'Culture' => l10n.interestCulture,
      _ => interest,
    };
  }

  Future<void> _showLanguagePicker() async {
    final selectedLanguage = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final l10n = sheetContext.l10n;
        final currentLanguage = AppServices.locale.languageCode;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                  child: Text(
                    l10n.selectLanguage,
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                ),
                RadioGroup<String>(
                  groupValue: currentLanguage,
                  onChanged: (value) {
                    if (value != null) Navigator.pop(sheetContext, value);
                  },
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        value: 'th',
                        title: Text(l10n.languageThai),
                      ),
                      RadioListTile<String>(
                        value: 'en',
                        title: Text(l10n.languageEnglish),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedLanguage != null) {
      await AppServices.locale.setLanguage(selectedLanguage);
    }
  }

  Future<void> _deletePlan(int tripId, AppLocalizations l10n) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.deletePlan),
          content: Text(l10n.deletePlanConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(l10n.deletePlan),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    if (mounted) setState(() => _loadingPlans = true);
    final result = await AppServices.trips.deletePlan(tripId);
    if (result['success'] == true) {
      _loadSavedPlans();
    } else {
      if (mounted) {
        setState(() => _loadingPlans = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to delete plan'),
          ),
        );
      }
    }
  }

  Widget _savedPlanCard(Map<String, dynamic> plan, AppLocalizations l10n, Color brandGold) {
    final int id = plan['id'];
    final String destination = plan['destination'] ?? 'Unknown';
    final String province = plan['province'] ?? '';
    final int days = plan['days'] ?? 1;
    final String title = province.isNotEmpty && destination != province 
        ? '$destination, $province' 
        : destination;
        
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: brandGold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.map_outlined, color: brandGold),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            l10n.planDaysCount(days),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          onSelected: (value) {
            if (value == 'delete') {
              _deletePlan(id, l10n);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'delete',
              child: Text(l10n.deletePlan, style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
        onTap: () {
          if (widget.onViewPlan != null) {
            widget.onViewPlan!(id);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PlanScreen(initialTripId: id)),
            ).then((_) => _loadSavedPlans());
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color brandGold = Color(0xFFF4C025);
    final String userEmail = AppServices.auth.currentUser?['email'] ?? '';
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: widget.onBackTap,
        ),
        title: Text(
          l10n.profile,
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
            // ส่วนรูปโปรไฟล์ผู้ใช้
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
                  backgroundImage: mediaImageProvider(
                    AppServices.media.fullUrl(_profileImageUrl).isNotEmpty
                        ? AppServices.media.fullUrl(_profileImageUrl)
                        : AppServices.media.defaultAvatarUrl,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ชื่อผู้ใช้และอีเมล
            Text(
              _username.isNotEmpty ? _username : l10n.setYourName,
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

            // ส่วนความสนใจ
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.myInterests,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    TextButton(
                      onPressed: _showEditInterestsDialog,
                      child: Text(
                        l10n.edit,
                        style: const TextStyle(
                          color: brandGold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _interests.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          l10n.noInterests,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
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
                              _interestLabel(context, interest),
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

            Container(
              decoration: BoxDecoration(
                color: const Color(0xfffff8e4),
                borderRadius: BorderRadius.circular(18),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                leading: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: brandGold.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.public, color: brandGold),
                ),
                title: Text(
                  l10n.travelFootprint,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    l10n.travelFootprintSubtitle,
                    style: const TextStyle(fontSize: 12, height: 1.3),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, color: brandGold),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TravelFootprintScreen(),
                  ),
                ),
              ),
            ),
            const Divider(height: 40, thickness: 1),

            // Saved Plans Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.savedPlans,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    if (_loadingPlans)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: brandGold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!_loadingPlans && _savedPlans.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      l10n.noSavedPlans,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
        ..._savedPlans.map((plan) => _savedPlanCard(plan, l10n, brandGold)),
              ],
            ),
            const Divider(height: 40, thickness: 1),

            // ส่วนการตั้งค่า
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settings,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),

                // รายการตั้งค่าบัญชี
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.manage_accounts_outlined,
                    color: Colors.black54,
                  ),
                  title: Text(l10n.accountSettings),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AccountSettingsScreen(),
                      ),
                    );
                    // โหลดข้อมูลโปรไฟล์ใหม่เมื่อกลับจากหน้าตั้งค่าบัญชี
                    setState(() => _loadUserData());
                  },
                ),

                // การเลือกภาษา
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.translate_outlined,
                    color: Colors.black54,
                  ),
                  title: Text(l10n.language),
                  trailing: Text(
                    AppServices.locale.languageCode == 'th'
                        ? l10n.languageThai
                        : l10n.languageEnglish,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  onTap: _showLanguagePicker,
                ),

                // Auto Diary
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: brandGold,
                  secondary: const Icon(
                    Icons.location_on_outlined,
                    color: Colors.black54,
                  ),
                  title: Text(l10n.autoDiary),
                  subtitle: Text(
                    l10n.autoDiarySubtitle,
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: _autoDiaryEnabled,
                  onChanged: (value) async {
                    setState(() => _autoDiaryEnabled = value);
                    final messenger = ScaffoldMessenger.of(context);
                    await AppServices.diaryAutomation.toggle(value);
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            value
                                ? l10n.autoDiaryEnabled
                                : l10n.autoDiaryDisabled,
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 40),

            // ปุ่มออกจากระบบ
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandGold,
                  foregroundColor: Colors.black,
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
                child: Text(l10n.logOut),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
