import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _organizationController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _organizationController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService.forgotPassword(
        identifier: _identifierController.text.trim(),
        organizationSlug: _organizationController.text.trim(),
      );

      if (!mounted) return;
      
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text(
              'If an account exists, you will receive an email to reset your password.',
              style: TextStyle(color: Colors.white),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

      Navigator.of(context).pop(); 
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.toString(), style: const TextStyle(color: Colors.white)),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon, required bool isDark}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
      prefixIcon: Icon(icon, color: isDark ? AppColors.darkIcon : AppColors.lightIcon),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                children: [
                  const Icon(Icons.lock_reset, size: 70, color: AppColors.primaryCyan),
                  const SizedBox(height: 24),
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
                          Text('Reset Password', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                          const SizedBox(height: 8),
                          Text('Enter your account identifier and company slug to receive a reset link.', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                          const SizedBox(height: 24),
                          
                          TextFormField(
                            controller: _identifierController,
                            style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                            decoration: _inputDecoration(hint: 'Email, Mobile, or Employee ID', icon: Icons.person_outline, isDark: isDark),
                            validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 15),

                          TextFormField(
                            controller: _organizationController,
                            style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                            decoration: _inputDecoration(hint: 'Company Slug (e.g. acme-corp)', icon: Icons.apartment_outlined, isDark: isDark),
                            validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submitRequest,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryCyan,
                                foregroundColor: AppColors.darkBackground,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: AppColors.darkBackground, strokeWidth: 2))
                                  : const Text('Send Reset Link', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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