import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'force_password_change_screen.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'package:geolocator/geolocator.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _organizationController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _organizationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  Future<Map<String, dynamic>?> _getDeviceLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      
      if (permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracyMeters': position.accuracy,
        'locationSource': 'device_gps',
      };
    } catch (e) {
      return null;
    }
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final locationData = await _getDeviceLocation();

      final requiresPasswordChange = await _authService.login(
        identifier: _identifierController.text.trim(),
        organizationSlug: _organizationController.text.trim(),
        password: _passwordController.text,
        locationData: locationData,
      );

      if (!mounted) return;
      
      if (requiresPasswordChange) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ForcePasswordChangeScreen()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon, required bool isDark, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
      prefixIcon: Icon(icon, color: isDark ? AppColors.darkIcon : AppColors.lightIcon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primaryCyan, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.error)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 70,
                    errorBuilder: (context, error, stackTrace) => 
                      const Icon(Icons.business, size: 70, color: AppColors.primaryCyan),
                  ),
                  const SizedBox(height: 12),
                  Text('Employee Attendance', style: TextStyle(fontSize: 15, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                  const SizedBox(height: 35),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sign in', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                          const SizedBox(height: 8),
                          Text('Enter your employee credentials to continue.', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _identifierController,
                            style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                            decoration: _inputDecoration(hint: 'Employee ID / Email', icon: Icons.person_outline, isDark: isDark),
                            validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 15),
                          TextFormField(
                            controller: _organizationController,
                            style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                            decoration: _inputDecoration(hint: 'Organization Slug', icon: Icons.apartment_outlined, isDark: isDark),
                            validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 15),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _hidePassword,
                            style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                            onFieldSubmitted: (_) => _login(),
                            decoration: _inputDecoration(
                              hint: 'Password',
                              icon: Icons.lock_outline,
                              isDark: isDark,
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _hidePassword = !_hidePassword),
                                icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: isDark ? AppColors.darkIcon : AppColors.lightIcon),
                              ),
                            ),
                            validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryCyan,
                                foregroundColor: AppColors.darkBackground,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: AppColors.darkBackground, strokeWidth: 2))
                                  : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
                              },
                              child: const Text('Forgot Password?', style: TextStyle(color: AppColors.primaryCyan, fontSize: 14)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}