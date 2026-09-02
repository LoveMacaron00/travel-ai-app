import 'package:flutter/material.dart';
import 'package:myapp/l10n/l10n.dart';
import 'package:myapp/screen/home_screen.dart';
import 'package:myapp/screen/profile_screen.dart';
import 'package:myapp/screen/map_screen.dart';
import 'package:myapp/screen/plan_screen.dart';
import 'package:myapp/screen/travel_diary_screen.dart';
import 'package:myapp/screen/travel_footprint_screen.dart';
import 'package:myapp/screen/feedback_history_screen.dart';
import 'package:myapp/screen/account_settings_screen.dart';
import 'package:myapp/services/location_service.dart';
import 'package:myapp/services/app_services.dart';

/// Shell หลังเข้าสู่ระบบ เก็บแต่ละ tab ไว้ใน IndexedStack เพื่อรักษา state
/// เช่น ตำแหน่งแผนที่และรายการแผน เมื่อผู้ใช้สลับแท็บไปมา
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  bool _showingDiary = false;
  bool _showingFeedback = false;
  bool _showingFootprint = false;
  bool _showingAccountSettings = false;
  late final List<Widget?> _screens;
  final GlobalKey<MapScreenState> _mapScreenKey = GlobalKey<MapScreenState>();
  final GlobalKey<ProfileScreenState> _profileScreenKey =
      GlobalKey<ProfileScreenState>();

  @override
  void initState() {
    super.initState();
    _screens = List<Widget?>.filled(4, null);
    _screens[0] = _createScreen(0);
    
    // Register navigation callback for showing destinations on map
    AppServices.navigator.registerShowDestinationCallback(_showDestinationOnMap);
    AppServices.tripGenerationStatus.addListener(_onTripStatusChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (LocationService.instance.currentPosition == null) {
        await LocationService.instance.refresh(openSettingsWhenDenied: false);
      }
      await LocationService.instance.startTracking();
      await AppServices.diaryAutomation.start();
    });
  }

  void _onTripStatusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppServices.tripGenerationStatus.removeListener(_onTripStatusChanged);
    AppServices.diaryAutomation.stop();
    LocationService.instance.stopTracking();
    AppServices.navigator.clearCallback();
    super.dispose();
  }

  void _viewPlan(int tripId) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _showingDiary = false;
      _showingFeedback = false;
      _showingFootprint = false;
      _showingAccountSettings = false;
      _selectedIndex = 2;
      // ใช้ UniqueKey เพื่อให้กดดู trip เดิมซ้ำหลังกดย้อนกลับแล้วยังโหลดใหม่ได้ (ไม่ติด state เดิมที่ _plan==null)
      _screens[2] = PlanScreen(
        key: ValueKey('plan_${tripId}_${DateTime.now().millisecondsSinceEpoch}'),
        initialTripId: tripId,
        onBackFromSavedView: () {
          setState(() {
            _screens[2] = const PlanScreen();
            _selectedIndex = 3;
          });
        },
      );
    });
  }

  Widget _createScreen(int index) {
    // สร้างหน้าจอเมื่อเปิดแท็บครั้งแรก เพื่อลดงานตอนเริ่มแอป
    switch (index) {
      case 0:
        return HomeScreen(
          onProfileTap: () => _selectTab(3),
          onPlanTap: () => _selectTab(2),
          onDiaryTap: _showDiary,
          onExploreDestination: _showDestinationOnMap,
        );
      case 1:
        return MapScreen(key: _mapScreenKey);
      case 2:
        return const PlanScreen();
      case 3:
        return ProfileScreen(
          key: _profileScreenKey,
          onBackTap: () => _selectTab(0),
          onViewPlan: _viewPlan,
          onFeedbackTap: _showFeedback,
          onFootprintTap: _showFootprint,
          onAccountSettingsTap: _showAccountSettings,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _selectTab(int index) {
    setState(() {
      _showingDiary = false;
      _showingFeedback = false;
      _showingFootprint = false;
      _showingAccountSettings = false;
      _screens[index] ??= _createScreen(index);
      _selectedIndex = index;
    });
  }

  void _showDiary() {
    setState(() {
      _showingFeedback = false;
      _showingFootprint = false;
      _showingAccountSettings = false;
      _showingDiary = true;
    });
  }

  void _showFeedback() {
    setState(() {
      _showingDiary = false;
      _showingFootprint = false;
      _showingAccountSettings = false;
      _showingFeedback = true;
    });
  }

  void _showFootprint() {
    setState(() {
      _showingDiary = false;
      _showingFeedback = false;
      _showingAccountSettings = false;
      _showingFootprint = true;
    });
  }

  void _showAccountSettings() {
    setState(() {
      _showingDiary = false;
      _showingFeedback = false;
      _showingFootprint = false;
      _showingAccountSettings = true;
    });
  }

  void _hideAccountSettings() {
    setState(() => _showingAccountSettings = false);
    // รีเฟรชโปรไฟล์เมื่อกลับจากหน้าตั้งค่าบัญชี (รอให้ IndexedStack mount ก่อน)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _profileScreenKey.currentState?.refreshProfile();
    });
  }

  void _onItemTapped(int index) {
    _selectTab(index);
  }

  void _showDestinationOnMap(int destinationId) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _showingDiary = false;
      _showingFeedback = false;
      _showingFootprint = false;
      _showingAccountSettings = false;
    });
    if (_selectedIndex != 1) {
      _selectTab(1);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapScreenKey.currentState?.showDestination(destinationId);
    });
  }

  Widget _buildTripBanner(BuildContext context) {
    final status = AppServices.tripGenerationStatus;
    if (!status.isActive) return const SizedBox.shrink();
    // ถ้าอยู่หน้า Plan อยู่แล้ว ไม่ต้องโชว์ tap bar ซ้อนกับหน้ากำลังสร้าง
    final isOnPlanTab = _selectedIndex == 2 &&
        !_showingDiary &&
        !_showingFeedback &&
        !_showingFootprint &&
        !_showingAccountSettings;
    if (isOnPlanTab) return const SizedBox.shrink();

    final isGenerating = status.isGenerating;
    final isSuccess = status.isSuccess;
    final isError = status.isError;

    final Color bgColor;
    final IconData icon;
    final String title;
    final String subtitle;
    final Widget? trailing;

    if (isGenerating) {
      bgColor = const Color(0xFFF4C025);
      icon = Icons.auto_awesome;
      title = context.l10n.designingTrip;
      subtitle = context.l10n.tripReadyTapHint;
      trailing = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: Colors.black87,
        ),
      );
    } else if (isSuccess) {
      bgColor = const Color(0xFF2E7D32);
      icon = Icons.check_circle;
      title = context.l10n.tripReady;
      subtitle = context.l10n.tripReadyTapHint;
      trailing = const Icon(Icons.chevron_right, color: Colors.white, size: 20);
    } else {
      bgColor = const Color(0xFFC62828);
      icon = Icons.error_outline;
      title = context.l10n.tripGenerationFailed;
      subtitle = status.message ?? '';
      trailing = const Icon(Icons.close, color: Colors.white70, size: 18);
    }

    return Material(
      color: bgColor,
      child: InkWell(
        onTap: () {
          if (isSuccess) {
            _selectTab(2);
          } else if (isGenerating) {
            _selectTab(2);
          } else if (isError) {
            status.dismiss();
          }
        },
        child: SafeArea(
          top: false,
          bottom: false,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSuccess || isError ? Colors.white24 : Colors.black12,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: isSuccess || isError ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSuccess || isError ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSuccess || isError ? Colors.white70 : Colors.black54,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing,
                if (isSuccess || isError) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => status.dismiss(),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, color: Colors.white70, size: 18),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color brandGold = Color(0xFFF4C025);
    final l10n = context.l10n;

    return PopScope(
      canPop: !_showingDiary &&
          !_showingFeedback &&
          !_showingFootprint &&
          !_showingAccountSettings,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_showingDiary) {
          setState(() => _showingDiary = false);
        } else if (_showingFeedback) {
          setState(() => _showingFeedback = false);
        } else if (_showingFootprint) {
          setState(() => _showingFootprint = false);
        } else if (_showingAccountSettings) {
          _hideAccountSettings();
        }
      },
      child: Scaffold(
        body: _showingDiary
            ? TravelDiaryScreen(
                onBack: () => setState(() => _showingDiary = false),
              )
            : _showingFeedback
            ? FeedbackHistoryScreen(
                onBack: () => setState(() => _showingFeedback = false),
              )
            : _showingFootprint
            ? TravelFootprintScreen(
                onBack: () => setState(() => _showingFootprint = false),
                onOpenDiary: _showDiary,
              )
            : _showingAccountSettings
                ? AccountSettingsScreen(onBack: _hideAccountSettings)
                : IndexedStack(
                index: _selectedIndex,
                children: List.generate(
                  _screens.length,
                  (index) => _screens[index] ?? const SizedBox.shrink(),
                ),
              ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _buildTripBanner(context),
            ),
            BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedItemColor: brandGold,
              unselectedItemColor: Colors.black38,
              showUnselectedLabels: true,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home_outlined),
                  activeIcon: const Icon(Icons.home),
                  label: l10n.home,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.map_outlined),
                  activeIcon: const Icon(Icons.map),
                  label: l10n.map,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.calendar_today_outlined),
                  activeIcon: const Icon(Icons.calendar_today),
                  label: l10n.plan,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.person_outline),
                  activeIcon: const Icon(Icons.person),
                  label: l10n.profile,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
