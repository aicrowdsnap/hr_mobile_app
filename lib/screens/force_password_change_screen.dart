import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';

class ForcePasswordChangeScreen extends StatefulWidget {
  final bool isVoluntary;
  const ForcePasswordChangeScreen({super.key, this.isVoluntary = false});

  @override
  State<ForcePasswordChangeScreen> createState() => _ForcePasswordChangeScreenState();
}

class _ForcePasswordChangeScreenState extends State<ForcePasswordChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.isVoluntary) {
        await _authService.changePassword(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
        );
      } else {
        await _authService.forcePasswordChange(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
        );
      }

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isVoluntary ? 'Password updated successfully!' : 'Security credentials updated! Proceeding to dashboard.'),
          backgroundColor: AppColors.success,
        ),
      );

      if (widget.isVoluntary) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      String errorMsg = e.toString();
      if (errorMsg.contains('Account security state does not require')) {
        errorMsg = 'Your account does not require a mandatory rotation. Please use the standard change password feature.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg, style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    if (value.length < 8) return 'Must be at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Must contain uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Must contain lowercase letter';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Must contain numeric digit';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) return 'Must contain special character';
    if (value == _currentPasswordController.text) {
      return widget.isVoluntary 
        ? 'New password cannot be the same as current password'
        : 'New password cannot be the same as temporary password';
    }
    return null;
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon, required bool isHidden, required VoidCallback toggleVisibility, required bool isDark}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
      prefixIcon: Icon(icon, color: isDark ? AppColors.darkIcon : AppColors.lightIcon),
      suffixIcon: IconButton(
        onPressed: toggleVisibility,
        icon: Icon(isHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: isDark ? AppColors.darkIcon : AppColors.lightIcon),
      ),
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
      appBar: widget.isVoluntary 
        ? AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ) 
        : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                children: [
                  Icon(widget.isVoluntary ? Icons.lock_reset : Icons.security, size: 70, color: AppColors.primaryCyan),
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
                          Text(
                            widget.isVoluntary ? 'Change Password' : 'Security Update Required', 
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.isVoluntary 
                              ? 'Enter your current password and choose a new secure password.'
                              : 'Your workplace credentials use a temporary system default password. Please choose a new secure password.', 
                            style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 13)
                          ),
                          const SizedBox(height: 24),
                          
                          TextFormField(
                            controller: _currentPasswordController,
                            obscureText: _hideCurrent,
                            style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                            decoration: _inputDecoration(
                              hint: widget.isVoluntary ? 'Current Password' : 'Temporary Default Password', 
                              icon: Icons.lock_outline,
                              isHidden: _hideCurrent,
                              toggleVisibility: () => setState(() => _hideCurrent = !_hideCurrent),
                              isDark: isDark
                            ),
                            validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 15),

                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _hideNew,
                            style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                            decoration: _inputDecoration(
                              hint: 'New Secure Password', 
                              icon: Icons.vpn_key_outlined,
                              isHidden: _hideNew,
                              toggleVisibility: () => setState(() => _hideNew = !_hideNew),
                              isDark: isDark
                            ),
                            validator: _validateNewPassword,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 15),

                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _hideConfirm,
                            style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                            decoration: _inputDecoration(
                              hint: 'Confirm New Password', 
                              icon: Icons.check_circle_outline,
                              isHidden: _hideConfirm,
                              toggleVisibility: () => setState(() => _hideConfirm = !_hideConfirm),
                              isDark: isDark
                            ),
                            validator: (value) {
                              if (value != _newPasswordController.text) return 'Passwords do not match';
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _updatePassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryCyan,
                                foregroundColor: AppColors.darkBackground,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text(widget.isVoluntary ? 'Update Password' : 'Update Password & Continue', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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