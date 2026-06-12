import 'package:flutter/material.dart';
import 'package:myapp/screen/welcome_screen.dart';
import 'package:myapp/screen/main_navigation_screen.dart';
import 'package:myapp/services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.initSession();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.amber, useMaterial3: false),
      home: ApiService.token != null ? const MainNavigationScreen() : const HomeScreen(),
    );
  }
}
