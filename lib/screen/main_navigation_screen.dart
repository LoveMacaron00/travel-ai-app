import 'package:flutter/material.dart';
import 'package:myapp/l10n/l10n.dart';
import 'package:myapp/screen/home_screen.dart';
import 'package:myapp/screen/profile_screen.dart';
import 'package:myapp/screen/map_screen.dart';
import 'package:myapp/screen/plan_screen.dart';
import 'package:myapp/screen/travel_diary_screen.dart';
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
  late final List<Widget?> _screens;
  final GlobalKey<MapScreenState> _mapScreenKey = GlobalKey<MapScreenState>();

  @override
  void initState() {
    super.initState();
    _screens = List<Widget?>.filled(4, null);
    _screens[0] = _createScreen(0);
    
    // Register navigation callback for showing destinations on map
    AppServices.navigator.registerShowDestinationCallback(_showDestinationOnMap);
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (LocationService.instance.currentPosition == null) {
        await LocationService.instance.refresh(openSettingsWhenDenied: false);
      }
      await LocationService.instance.startTracking();
      await AppServices.diaryAutomation.start();
    });
  }

  @override
  void dispose() {
    AppServices.diaryAutomation.stop();
    LocationService.instance.stopTracking();
    AppServices.navigator.clearCallback();
    super.dispose();
  }

  void _viewPlan(int tripId) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _showingDiary = false;
      _selectedIndex = 2;
      _screens[2] = PlanScreen(
        key: ValueKey('plan_$tripId'),
        initialTripId: tripId,
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
          onBackTap: () => _selectTab(0),
          onViewPlan: _viewPlan,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _selectTab(int index) {
    setState(() {
      _showingDiary = false;
      _screens[index] ??= _createScreen(index);
      _selectedIndex = index;
    });
  }

  void _showDiary() {
    setState(() => _showingDiary = true);
  }

  void _onItemTapped(int index) {
    _selectTab(index);
  }

  void _showDestinationOnMap(int destinationId) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (_selectedIndex != 1) {
      _selectTab(1);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapScreenKey.currentState?.showDestination(destinationId);
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color brandGold = Color(0xFFF4C025);
    final l10n = context.l10n;

    return PopScope(
      canPop: !_showingDiary,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showingDiary) {
          setState(() => _showingDiary = false);
        }
      },
      child: Scaffold(
        body: _showingDiary
            ? TravelDiaryScreen(
                onBack: () => setState(() => _showingDiary = false),
              )
            : IndexedStack(
                index: _selectedIndex,
                children: List.generate(
                  _screens.length,
                  (index) => _screens[index] ?? const SizedBox.shrink(),
                ),
              ),
        bottomNavigationBar: BottomNavigationBar(
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
      ),
    );
  }
}
