import 'package:flutter/material.dart';
import 'package:form_field_validator/form_field_validator.dart';
import 'package:myapp/model/profile.dart';
import 'package:myapp/screen/sign_up_screen.dart';
import 'package:myapp/screen/main_navigation_screen.dart';
import 'package:myapp/services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formkey = GlobalKey<FormState>();
  final Profile profile = Profile();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    if (!formkey.currentState!.validate()) {
      return;
    }

    formkey.currentState!.save();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final loginResult = await ApiService.loginUser(
        email: profile.email!,
        password: profile.password!,
      );

      if (!loginResult['success']) {
        if (mounted) {
          setState(() {
            _errorMessage =
                loginResult['message']?.toString() ??
                'Login failed. Please try again.';
          });
        }
        return;
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Network error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    const Color borderGray = Color(0xFF747474);
    const Color errorRed = Color(0xFFE53935);

    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 15, color: borderGray),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      prefixIcon: Icon(prefixIcon, size: 22, color: borderGray),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderGray, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderGray, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderGray, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorRed, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorRed, width: 1.5),
      ),
      errorStyle: const TextStyle(color: errorRed, fontSize: 12, height: 1.2),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color brandGold = Color(0xFFF4C025);
    const Color bgGray = Color(0xFFFFFFFF);
    const Color borderGray = Color(0xFF747474);

    return Scaffold(
      backgroundColor: bgGray,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(34, 50, 35, 32),
          child: Form(
            key: formkey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back,
                    size: 24,
                    color: Colors.black87,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
                const SizedBox(height: 34),
                const Text(
                  'Login a User\nAccount',
                  style: TextStyle(
                    color: brandGold,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    height: 1.22,
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    'Welcome back! Please enter your details.',
                    style: TextStyle(
                      fontSize: 14,
                      color: borderGray,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: 44),
                const Text(
                  'Email',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  validator: MultiValidator([
                    RequiredValidator(errorText: 'Email is required'),
                    EmailValidator(errorText: 'Email is invalid'),
                  ]).call,
                  keyboardType: TextInputType.emailAddress,
                  onSaved: (value) => profile.email = value,
                  style: const TextStyle(fontSize: 15, color: borderGray),
                  decoration: _buildInputDecoration(
                    hintText: 'Enter your email.',
                    prefixIcon: Icons.mail_outline,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  validator: RequiredValidator(
                    errorText: 'Password is required',
                  ).call,
                  obscureText: _obscurePassword,
                  onSaved: (value) => profile.password = value,
                  style: const TextStyle(fontSize: 15, color: borderGray),
                  decoration: _buildInputDecoration(
                    hintText: 'Enter your password.',
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 22,
                        color: borderGray,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Forget password?',
                      style: TextStyle(
                        color: brandGold,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFE53935),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFFE53935),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFE53935),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandGold,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Sign In'),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
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
                    child: const Text.rich(
                      TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(
                          color: borderGray,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        children: [
                          TextSpan(
                            text: 'Sign Up',
                            style: TextStyle(
                              color: brandGold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
