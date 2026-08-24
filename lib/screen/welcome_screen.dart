import 'package:flutter/material.dart';
import 'package:myapp/screen/sign_in_screen.dart';
import 'package:myapp/screen/sign_up_screen.dart';

/// หน้าเริ่มต้นสำหรับผู้ใช้ที่ยังไม่มี session ก่อนเข้าสู่ flow Login/Register
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color brandGold = Color(0xFFF4C025);
    const Color backgroundGray = Color.fromARGB(255, 255, 255, 255);
    const String logoAsset = 'assets/images/gothai_logo.png';
    const double designWidth = 412;
    const double designHeight = 917;

    return Scaffold(
      backgroundColor: backgroundGray,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: designWidth,
                height: designHeight,
                child: Stack(
                  children: [
                    Positioned(
                      left: 35,
                      top: 143,
                      child: Text(
                        'Welcome to Application',
                        style: const TextStyle(
                          color: brandGold,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 82,
                      top: 294,
                      width: 248,
                      height: 288,
                      child: Image.asset(logoAsset, fit: BoxFit.contain),
                    ),
                    Positioned(
                      left: 22,
                      top: 694,
                      width: 368,
                      height: 65,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandGold,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        child: const Text('Sign In'),
                      ),
                    ),
                    Positioned(
                      left: 22,
                      top: 786,
                      width: 368,
                      height: 65,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: brandGold,
                          backgroundColor: Colors.transparent,
                          side: const BorderSide(color: brandGold, width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: const Text('Sign Up'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
