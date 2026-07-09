// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:myapp/screen/home_screen.dart';
import 'package:myapp/screen/profile_screen.dart';
import 'package:myapp/screen/map_screen.dart';
import 'package:myapp/screen/plan_screen.dart';

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

    // List ของหน้าจอที่จะแสดงในแต่ละแท็บ
    final List<Widget> screens = [

      HomeScreen(
        onProfileTap: () {
          setState(() {
            _selectedIndex = 3; // Switch ไปยังแท็บ Profile
          });
        },
      ),
      
      MapScreen(),
     
      PlanScreen(),

      ProfileScreen(
        onBackTap: () {
          setState(() {
            _selectedIndex = 0; // ย้อนกลับไปยังแท็บ Home
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
