import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/attendance_status.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'attendance_screen.dart';
import 'login_screen.dart';
import 'my_calendar_screen.dart';
import 'leave_screen.dart';
import '../main.dart';
import 'force_password_change_screen.dart';
import '../widgets/day_night_switch.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _attendanceService = AttendanceService();
  final _authService = AuthService();
  
  AttendanceStatus? _attendance;
  Map<String, dynamic>? _employeeProfile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _attendanceService.getCurrentStatus();
      final employeeData = result['employee'] as Map<String, dynamic>?;
      final employeeId = employeeData?['id']?.toString();

      if (!mounted) return;
      setState(() {
        _attendance = AttendanceStatus.fromJson(result);
        _employeeProfile = employeeData;
      });

      if (employeeId != null) {
        final slNow = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
        final todayStr = DateFormat('yyyy-MM-dd').format(slNow);
        
        final history = await _attendanceService.getDailyAttendanceRecords(
          employeeId: employeeId, 
          year: slNow.year, 
          month: slNow.month
        );

        Map<String, dynamic>? todayRecord;
        for (var a in history) {
          if (a['attendanceDate'] != null) {
            final dateStr = a['attendanceDate'].toString().split('T')[0];
            if (dateStr == todayStr) {
              todayRecord = a as Map<String, dynamic>;
              break;
            }
          }
        }

        if (!(_attendance?.isClockedIn ?? false) && todayRecord != null) {
          setState(() {
            _attendance = AttendanceStatus(
              status: 'clocked_out',
              clockInTime: todayRecord?['clockInTime']?.toString(),
              clockOutTime: todayRecord?['clockOutTime']?.toString(),
              date: todayRecord?['attendanceDate']?.toString(),
              totalWorkingMinutes: todayRecord?['totalWorkingMinutes'],
            );
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                'Confirm Logout',
                style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Are you sure you want to log out of your account?',
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 14),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                      ),
                      child: Text('Cancel', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Logout', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    try { await _authService.logout(); } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false,
    );
  }

  void _showProfileDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        final userData = _employeeProfile?['user'] as Map<String, dynamic>?;
        final name = userData?['name'] ?? _employeeProfile?['name'] ?? 'Employee';
        final email = userData?['email'] ?? 'Not specified';
        final designation = _employeeProfile?['designation']?.toString().replaceAll('_', ' ') ?? 'N/A';
        final department = _employeeProfile?['department']?.toString().replaceAll('_', ' ') ?? 'N/A';
        final employeeCode = _employeeProfile?['employeeCode'] ?? 'N/A';
        final employmentType = _employeeProfile?['employmentType'] ?? 'N/A';
        final status = _employeeProfile?['status'] ?? 'Active';

        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryCyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded, color: AppColors.primaryCyan),
              ),
              const SizedBox(width: 12),
              Text('User Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileDetailRow(label: 'Full Name', value: name),
                _ProfileDetailRow(label: 'Email Address', value: email),
                _ProfileDetailRow(label: 'Employee Code', value: employeeCode),
                _ProfileDetailRow(label: 'Designation', value: designation.toUpperCase()),
                _ProfileDetailRow(label: 'Department', value: department.toUpperCase()),
                _ProfileDetailRow(label: 'Employment Type', value: employmentType.toUpperCase()),
                _ProfileDetailRow(label: 'Account Status', value: status.toUpperCase()),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryCyan)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userData = _employeeProfile?['user'] as Map<String, dynamic>?;
    final employeeName = userData?['name'] ?? 'Employee';
    final designation = _employeeProfile?['designation']?.toString().replaceAll('_', ' ') ?? 'Employee';
    final department = _employeeProfile?['department']?.toString().replaceAll('_', ' ') ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground, 
      appBar: AppBar(
        title: Image.asset('assets/images/logo.png', height: 26, errorBuilder: (c, e, s) => Text('NovaHR', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary))),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, currentMode, _) {
              final isCurrentDark = currentMode == ThemeMode.dark;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: DayNightSwitch(
                    isDarkMode: isCurrentDark,
                    onChanged: (val) {
                      themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                    },
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.settings_rounded, color: isDark ? AppColors.darkIcon : AppColors.lightIcon), 
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ForcePasswordChangeScreen(isVoluntary: true)),
              );
            },
          ),
          IconButton(icon: Icon(Icons.account_circle_rounded, color: isDark ? AppColors.darkIcon : AppColors.lightIcon), onPressed: _showProfileDialog),
          IconButton(icon: Icon(Icons.logout_rounded, color: isDark ? AppColors.darkIcon : AppColors.lightIcon), onPressed: _logout),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      color: AppColors.primaryCyan.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        employeeName.isNotEmpty ? employeeName[0].toUpperCase() : 'E',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryCyan),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome back', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(employeeName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                        const SizedBox(height: 3),
                        Text(
                          '${designation.toUpperCase()}${department.isNotEmpty ? ' • ${department.toUpperCase()}' : ''}',
                          style: const TextStyle(color: AppColors.primaryCyan, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Dashboard Overview', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppColors.primaryCyan)))
            else if (_error != null)
              _ErrorCard(message: _error!, onRetry: _loadDashboardData)
            else
              AttendanceStatusCard(attendance: _attendance),
            const SizedBox(height: 20),
            _QuickActionCard(
              icon: Icons.fingerprint_rounded,
              iconColor: AppColors.primaryCyan,
              title: 'Mark Attendance',
              subtitle: 'Clock in or clock out for your shift',
              onTap: () async { await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AttendanceScreen())); _loadDashboardData(); },
            ),
            const SizedBox(height: 14),
            _QuickActionCard(
              icon: Icons.calendar_month_rounded,
              iconColor: AppColors.skyBlue,
              title: 'My Schedule & History',
              subtitle: 'View shifts, holidays, and past records',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyCalendarScreen())),
            ),
            const SizedBox(height: 14),
            _QuickActionCard(
              icon: Icons.event_note_rounded,
              iconColor: Colors.orange.shade400,
              title: 'Leave Management',
              subtitle: 'Apply for leave & check balances',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeaveScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileDetailRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
        ],
      ),
    );
  }
}

class AttendanceStatusCard extends StatelessWidget {
  final AttendanceStatus? attendance;
  const AttendanceStatusCard({super.key, required this.attendance});

  String _formatTime(String? value) {
    if (value == null || value.trim().isEmpty) return '--';
    try {
      final cleanValue = value.replaceAll('Z', '').replaceAll('z', '');
      DateTime dateTime = DateTime.parse(cleanValue);

      final hour = dateTime.hour == 0 ? 12 : dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } catch (_) { return value; }
  }

  String _formatWorkingHours() {
    int totalMins = attendance?.totalWorkingMinutes ?? 0;
    
    if ((attendance?.isClockedIn ?? false) && attendance?.clockInTime != null) {
      try {
        final cleanTime = attendance!.clockInTime!.replaceAll('Z', '').replaceAll('z', '');
        final clockInTime = DateTime.parse(cleanTime);
        totalMins = DateTime.now().difference(clockInTime).inMinutes;
      } catch (_) {}
    }

    if (totalMins <= 0) return '--';

    final hours = totalMins ~/ 60;
    final mins = totalMins % 60;

    if (hours == 0) return '$mins mins';
    if (mins == 0) return '$hours hrs';
    return '$hours hrs $mins mins';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIn = attendance?.isClockedIn ?? false;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceHighlight : AppColors.lightSurfaceHighlight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isIn ? AppColors.primaryCyan.withValues(alpha: 0.5) : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time_filled, color: isIn ? AppColors.primaryCyan : (isDark ? AppColors.darkIcon : AppColors.lightIcon)),
              const SizedBox(width: 10),
              Expanded(child: Text("Today's Attendance", style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontSize: 18, fontWeight: FontWeight.bold))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: isIn ? AppColors.primaryCyan : (isDark ? AppColors.darkBorder : AppColors.lightBorder), borderRadius: BorderRadius.circular(30)),
                child: Text(isIn ? 'CLOCKED IN' : 'CLOCKED OUT', style: TextStyle(color: isIn ? AppColors.darkBackground : AppColors.lightBackground, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: _HomeTime(title: 'Clock In', time: _formatTime(attendance?.clockInTime))),
              Expanded(child: _HomeTime(title: 'Clock Out', time: _formatTime(attendance?.clockOutTime))),
            ],
          ),
          const SizedBox(height: 15),
          Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Worked Time:', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 13)),
              Text(_formatWorkingHours(), style: const TextStyle(color: AppColors.primaryCyan, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeTime extends StatelessWidget {
  final String title;
  final String time;
  const _HomeTime({required this.title, required this.time});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 13)),
        const SizedBox(height: 5),
        Text(time, style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _QuickActionCard({required this.icon, required this.iconColor, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(19),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: isDark ? AppColors.darkIcon : AppColors.lightIcon),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 38),
          const SizedBox(height: 10),
          Text('Unable to load data', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry', style: TextStyle(color: AppColors.primaryCyan))),
        ],
      ),
    );
  }
}