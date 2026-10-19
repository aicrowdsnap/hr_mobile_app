import 'dart:async';

import 'package:flutter/material.dart';

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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _attendanceService = AttendanceService();
  final _authService = AuthService();

  AttendanceStatus? _attendance;
  Map<String, dynamic>? _employeeProfile;
  Map<String, dynamic>? _todayShiftAssignment;

  bool _loading = true;
  bool _backgroundSyncing = false;
  String? _error;

  bool _hasShiftToday = false;
  bool _hasCompletedToday = false;

  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboardData();

    _syncTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
      _loadDashboardData(silent: true);
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadDashboardData(silent: true);
    }
  }

  Future<void> _loadDashboardData({bool silent = false}) async {
    if (silent && (_backgroundSyncing || _loading)) return;

    if (silent) {
      _backgroundSyncing = true;
    } else if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final snapshot = await _attendanceService.getTodaySnapshot();

      if (!mounted) return;

      setState(() {
        _attendance = snapshot.attendance;
        _employeeProfile = snapshot.employee;
        _todayShiftAssignment = snapshot.primaryShiftAssignment;
        _hasShiftToday = snapshot.hasShiftToday;
        _hasCompletedToday = snapshot.hasCompletedToday;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      // Keep already loaded dashboard data visible if only a background refresh
      // failed. A manual/initial load still shows the error card.
      if (!silent) {
        setState(() => _error = e.toString());
      }
    } finally {
      _backgroundSyncing = false;
      if (!silent && mounted) {
        setState(() => _loading = false);
      }
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
        onRefresh: () => _loadDashboardData(),
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
              _ErrorCard(message: _error!, onRetry: () => _loadDashboardData())
            else
              AttendanceStatusCard(
                attendance: _attendance,
                hasShiftAssigned: _hasShiftToday,
                hasCompletedToday: _hasCompletedToday,
                shiftAssignment: _todayShiftAssignment,
              ),
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
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeaveScreen())),
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
  final bool hasShiftAssigned;
  final bool hasCompletedToday;
  final Map<String, dynamic>? shiftAssignment;

  const AttendanceStatusCard({
    super.key,
    required this.attendance,
    required this.hasShiftAssigned,
    required this.hasCompletedToday,
    required this.shiftAssignment,
  });

  static const Duration _colomboOffset =
      Duration(hours: 5, minutes: 30);

  DateTime _colomboWallClockNow() {
    final colombo = DateTime.now().toUtc().add(_colomboOffset);
    return DateTime.utc(
      colombo.year,
      colombo.month,
      colombo.day,
      colombo.hour,
      colombo.minute,
      colombo.second,
    );
  }

  DateTime? _parseServerWallClock(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    try {
      var clean = value.trim();
      clean = clean.replaceFirst(RegExp(r'[zZ]$'), '');
      clean = clean.replaceFirst(RegExp(r'([+-]\d{2}:\d{2})$'), '');

      final parsed = DateTime.parse(clean);

      // The hosted attendance service stores punch timestamps with +05:30
      // already applied. Treat the returned date/time components as a wall
      // clock value instead of applying another timezone conversion.
      return DateTime.utc(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
      );
    } catch (_) {
      return null;
    }
  }

  String _formatTime(String? value) {
    final dateTime = _parseServerWallClock(value);
    if (dateTime == null) return '--';

    final hour = dateTime.hour == 0
        ? 12
        : dateTime.hour > 12
            ? dateTime.hour - 12
            : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  String _formatWorkingHours() {
    int? totalMins = attendance?.totalWorkingMinutes;

    if (attendance?.isClockedIn == true && attendance?.clockInTime != null) {
      final clockIn = _parseServerWallClock(attendance!.clockInTime);
      if (clockIn != null) {
        totalMins = _colomboWallClockNow().difference(clockIn).inMinutes;
      }
    }

    if (totalMins == null || totalMins < 0) return '--';

    final hours = totalMins ~/ 60;
    final mins = totalMins % 60;

    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  Map<String, dynamic>? get _shift {
    final raw = shiftAssignment?['shift'];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  String get _shiftName => _shift?['name']?.toString() ?? 'Assigned Shift';

  String get _shiftTime {
    final start = _shift?['startTime']?.toString();
    final end = _shift?['endTime']?.toString();

    if (start == null || end == null) return 'Time not available';
    return '$start - $end';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isClockedIn = attendance?.isClockedIn ?? false;

    late final Color statusColor;
    late final IconData statusIcon;
    late final String statusTitle;
    late final String statusBadge;
    late final String statusMessage;

    if (hasCompletedToday) {
      statusColor = AppColors.success;
      statusIcon = Icons.task_alt_rounded;
      statusTitle = 'Shift Completed';
      statusBadge = 'COMPLETED';
      statusMessage = 'Today\'s attendance has been completed.';
    } else if (attendance?.isOnBreak == true) {
      statusColor = AppColors.warning;
      statusIcon = Icons.coffee_rounded;
      statusTitle = 'On Break';
      statusBadge = 'BREAK';
      statusMessage = 'Your attendance is active and your break is in progress.';
    } else if (isClockedIn) {
      statusColor = AppColors.primaryCyan;
      statusIcon = Icons.access_time_filled_rounded;
      statusTitle = 'Currently Working';
      statusBadge = 'CLOCKED IN';
      statusMessage = 'Your attendance is active now.';
    } else if (hasShiftAssigned) {
      statusColor = AppColors.warning;
      statusIcon = Icons.schedule_rounded;
      statusTitle = 'Shift Assigned';
      statusBadge = 'NOT CLOCKED IN';
      statusMessage = 'Your shift is ready. Clock in to start attendance.';
    } else {
      statusColor =
          isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
      statusIcon = Icons.event_busy_rounded;
      statusTitle = 'No Shift Assigned';
      statusBadge = 'NO SHIFT';
      statusMessage = 'There is no shift assigned to you for today.';
    }

    final showAttendanceTimes = isClockedIn || hasCompletedToday;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceHighlight
            : AppColors.lightSurfaceHighlight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 23),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusMessage,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(30),
                  border:
                      Border.all(color: statusColor.withValues(alpha: 0.32)),
                ),
                child: Text(
                  statusBadge,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (hasShiftAssigned) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface
                    : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.work_history_outlined,
                    color: statusColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _shiftName,
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _shiftTime,
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (showAttendanceTimes) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _HomeTime(
                    title: 'Clock In',
                    time: _formatTime(attendance?.clockInTime),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HomeTime(
                    title: 'Clock Out',
                    time: isClockedIn
                        ? 'Working'
                        : _formatTime(attendance?.clockOutTime),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Divider(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isClockedIn ? 'Current Worked Time' : 'Total Worked Time',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  _formatWorkingHours(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                hasShiftAssigned
                    ? 'No clock-in has been recorded yet today.'
                    : 'Attendance actions are unavailable until a shift is assigned.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeTime extends StatelessWidget {
  final String title;
  final String time;
  final bool isDark;

  const _HomeTime({required this.title, required this.time, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 13)),
        const SizedBox(height: 5),
        Text(time, style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
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