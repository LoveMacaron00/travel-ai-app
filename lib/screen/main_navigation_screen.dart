// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:myapp/screen/dashboard_screen.dart';
import 'package:myapp/screen/profile_screen.dart';
import 'package:myapp/screen/map_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color brandGold = Color(0xFFF4C025);

    // List of screens corresponding to bottom bar items
    final List<Widget> screens = [
      DashboardScreen(
        onProfileTap: () {
          setState(() {
            _selectedIndex = 3; // Switch to Profile tab
          });
        },
      ),
      const MapScreen(),
      // Plan Screen Placeholder
      Scaffold(
        appBar: AppBar(
          title: const Text('Travel Planner', style: TextStyle(color: Colors.black87)),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today_outlined, size: 80, color: brandGold.withOpacity(0.6)),
              const SizedBox(height: 16),
              const Text(
                'AI Travel Planner',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create custom AI itineraries.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
      ProfileScreen(
        onBackTap: () {
          setState(() {
            _selectedIndex = 0; // Back to Home tab
          });
        },
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
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
