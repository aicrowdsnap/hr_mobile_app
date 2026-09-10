import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class ForcePasswordChangeScreen extends StatefulWidget {
  const ForcePasswordChangeScreen({super.key});

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
      await _authService.forcePasswordChange(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Security credentials updated! Proceeding to dashboard.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString(), style: const TextStyle(color: Colors.white)),
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
      return 'New password cannot be the same as temporary password';
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
      fillColor: const Color(0xFF2A3036),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade800)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF90CA28), width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.red)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2A3036),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                children: [
                  const Icon(Icons.security, size: 70, color: Color(0xFF90CA28)),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF343A40),
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
                          const Text('Security Update Required', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 8),
                          Text(
                            'Your workplace credentials use a temporary system default password. Please choose a new secure password.', 
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 13)
                          ),
                          const SizedBox(height: 24),
                          
                          // Current Password
                          TextFormField(
                            controller: _currentPasswordController,
                            obscureText: _hideCurrent,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(
                              hint: 'Temporary Default Password', 
                              icon: Icons.lock_outline,
                              isHidden: _hideCurrent,
                              toggleVisibility: () => setState(() => _hideCurrent = !_hideCurrent)
                            ),
                            validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 15),

                          // New Password
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _hideNew,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(
                              hint: 'New Custom Password', 
                              icon: Icons.vpn_key_outlined,
                              isHidden: _hideNew,
                              toggleVisibility: () => setState(() => _hideNew = !_hideNew)
                            ),
                            validator: _validateNewPassword,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 15),

                          // Confirm Password
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
                                backgroundColor: const Color(0xFF90CA28),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Update Password & Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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