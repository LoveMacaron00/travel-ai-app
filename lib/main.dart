import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/screen/welcome_screen.dart';
import 'package:myapp/screen/main_navigation_screen.dart';
import 'package:myapp/services/app_services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppServices.locale.init();
  // โหลด session ก่อนสร้าง widget แรก เพื่อไม่ให้หน้า Welcome กระพริบขึ้นมา
  // ระหว่างที่แอปกำลังตัดสินใจว่าผู้ใช้เคยเข้าสู่ระบบแล้วหรือไม่
  await AppServices.auth.initSession();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(AppServices.activity.resume());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(AppServices.activity.resume());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(AppServices.activity.pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(AppServices.activity.pause());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppServices.locale,
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        locale: AppServices.locale.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(primarySwatch: Colors.amber, useMaterial3: false),
        home: AppServices.auth.token != null
            ? const MainNavigationScreen()
            : const WelcomeScreen(),
      ),
    );
  }
}
