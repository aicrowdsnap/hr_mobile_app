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
          backgroundColor: Colors.green,
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
          backgroundColor: Colors.red,
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

  InputDecoration _inputDecoration({required String hint, required IconData icon, required bool isHidden, required VoidCallback toggleVisibility}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500),
      prefixIcon: Icon(icon, color: Colors.grey.shade500),
      suffixIcon: IconButton(
        onPressed: toggleVisibility,
        icon: Icon(isHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey.shade500),
      ),
      filled: true,
      fillColor: AppColors.darkBlue,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade800)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.brightCyan, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.red)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBlue,
      appBar: widget.isVoluntary 
        ? AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                  Icon(widget.isVoluntary ? Icons.lock_reset : Icons.security, size: 70, color: AppColors.brightCyan),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.darkPurple,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isVoluntary ? 'Change Password' : 'Security Update Required', 
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.isVoluntary 
                              ? 'Enter your current password and choose a new secure password.'
                              : 'Your workplace credentials use a temporary system default password. Please choose a new secure password.', 
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 13)
                          ),
                          const SizedBox(height: 24),
                          
                          TextFormField(
                            controller: _currentPasswordController,
                            obscureText: _hideCurrent,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(
                              hint: widget.isVoluntary ? 'Current Password' : 'Temporary Default Password', 
                              icon: Icons.lock_outline,
                              isHidden: _hideCurrent,
                              toggleVisibility: () => setState(() => _hideCurrent = !_hideCurrent)
                            ),
                            validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 15),

                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _hideNew,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(
                              hint: 'New Secure Password', 
                              icon: Icons.vpn_key_outlined,
                              isHidden: _hideNew,
                              toggleVisibility: () => setState(() => _hideNew = !_hideNew)
                            ),
                            validator: _validateNewPassword,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 15),

                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _hideConfirm,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(
                              hint: 'Confirm New Password', 
                              icon: Icons.check_circle_outline,
                              isHidden: _hideConfirm,
                              toggleVisibility: () => setState(() => _hideConfirm = !_hideConfirm)
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
                                backgroundColor: AppColors.brightCyan,
                                foregroundColor: AppColors.darkBlue,
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