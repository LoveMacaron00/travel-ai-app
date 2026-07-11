// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:myapp/screen/home_screen.dart';
import 'package:myapp/screen/profile_screen.dart';
import 'package:myapp/screen/map_screen.dart';
import 'package:myapp/screen/plan_screen.dart';
import 'package:myapp/services/location_service.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  late final List<Widget?> _screens;

  @override
  void initState() {
    super.initState();
    _screens = List<Widget?>.filled(4, null);
    _screens[0] = _createScreen(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && LocationService.instance.currentPosition == null) {
        LocationService.instance.refresh(openSettingsWhenDenied: false);
      }
    });
  }

  Widget _createScreen(int index) {
    switch (index) {
      case 0:
        return HomeScreen(onProfileTap: () => _selectTab(3));
      case 1:
        return const MapScreen();
      case 2:
        return const PlanScreen();
      case 3:
        return ProfileScreen(onBackTap: () => _selectTab(0));
      default:
        return const SizedBox.shrink();
    }
  }

  void _selectTab(int index) {
    setState(() {
      _screens[index] ??= _createScreen(index);
      _selectedIndex = index;
    });
  }

  void _onItemTapped(int index) {
    _selectTab(index);
  }

  @override
  Widget build(BuildContext context) {
    const Color brandGold = Color(0xFFF4C025);

    return Scaffold(
      body: IndexedStack(
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Plan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
