import 'package:flutter/material.dart';
import 'package:myapp/screen/welcome_screen.dart';
import 'package:myapp/screen/main_navigation_screen.dart';
import 'package:myapp/services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // โหลด session ก่อนสร้าง widget แรก เพื่อไม่ให้หน้า Welcome กระพริบขึ้นมา
  // ระหว่างที่แอปกำลังตัดสินใจว่าผู้ใช้เคยเข้าสู่ระบบแล้วหรือไม่
  await ApiService.initSession();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoThai',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.amber, useMaterial3: false),
      home: ApiService.token != null
          ? const MainNavigationScreen()
          : const WelcomeScreen(),
    );
  }
}
