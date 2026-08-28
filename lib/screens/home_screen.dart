import 'package:flutter/material.dart';

import '../models/attendance_status.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import 'attendance_screen.dart';
import 'login_screen.dart';
import 'my_calendar_screen.dart';

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
        final now = DateTime.now();
        final history = await _attendanceService.getDailyAttendanceRecords(employeeId: employeeId, year: now.year, month: now.month);

        Map<String, dynamic>? todayRecord;
        for (var a in history) {
          if (a['attendanceDate'] != null) {
            final d = DateTime.parse(a['attendanceDate'].toString()).toLocal();
            if (d.year == now.year && d.month == now.month && d.day == now.day) {
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
    try { await _authService.logout(); } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false,
    );
  }

  void _showProfileDialog() {
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
          backgroundColor: const Color(0xFF343A40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF90CA28).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded, color: Color(0xFF90CA28)),
              ),
              const SizedBox(width: 12),
              const Text('User Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF90CA28))),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userData = _employeeProfile?['user'] as Map<String, dynamic>?;
    final employeeName = userData?['name'] ?? 'Employee';
    final designation = _employeeProfile?['designation']?.toString().replaceAll('_', ' ') ?? 'Employee';
    final department = _employeeProfile?['department']?.toString().replaceAll('_', ' ') ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF2A3036),
      appBar: AppBar(
        title: Image.asset('assets/images/logo.png', height: 26, errorBuilder: (c, e, s) => const Text('NovaHR')),
        actions: [
          IconButton(icon: const Icon(Icons.account_circle_rounded), onPressed: _showProfileDialog),
          IconButton(icon: const Icon(Icons.logout_rounded), onPressed: _logout),
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
                color: const Color(0xFF343A40),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      color: const Color(0xFF90CA28).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        employeeName.isNotEmpty ? employeeName[0].toUpperCase() : 'E',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF90CA28)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome back', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(employeeName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 3),
                        Text(
                          '${designation.toUpperCase()}${department.isNotEmpty ? ' • ${department.toUpperCase()}' : ''}',
                          style: const TextStyle(color: Color(0xFF90CA28), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Dashboard Overview', style: TextStyle(color: Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFF90CA28))))
            else if (_error != null)
              _ErrorCard(message: _error!, onRetry: _loadDashboardData)
            else
              AttendanceStatusCard(attendance: _attendance),
            const SizedBox(height: 20),
            _QuickActionCard(
              icon: Icons.fingerprint_rounded,
              iconColor: const Color(0xFF90CA28),
              title: 'Mark Attendance',
              subtitle: 'Clock in or clock out for your shift',
              onTap: () async { await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AttendanceScreen())); _loadDashboardData(); },
            ),
            const SizedBox(height: 14),
            _QuickActionCard(
              icon: Icons.calendar_month_rounded,
              iconColor: Colors.blue.shade400,
              title: 'My Schedule & History',
              subtitle: 'View shifts, holidays, and past records',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyCalendarScreen())),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
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
      final dateTime = DateTime.parse(value).toLocal();
      final hour = dateTime.hour == 0 ? 12 : dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } catch (_) { return value; }
  }
  @override
  Widget build(BuildContext context) {
    final isIn = attendance?.isClockedIn ?? false;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2328), // Darker inset
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isIn ? const Color(0xFF90CA28).withValues(alpha: 0.5) : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time_filled, color: isIn ? const Color(0xFF90CA28) : Colors.grey.shade500),
              const SizedBox(width: 10),
              const Expanded(child: Text("Today's Attendance", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: isIn ? const Color(0xFF90CA28) : Colors.grey.shade600, borderRadius: BorderRadius.circular(30)),
                child: Text(isIn ? 'CLOCKED IN' : 'CLOCKED OUT', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(child: _HomeTime(title: 'Clock In', time: _formatTime(attendance?.clockInTime))),
              Expanded(child: _HomeTime(title: 'Clock Out', time: _formatTime(attendance?.clockOutTime))),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        const SizedBox(height: 5),
        Text(time, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
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
    return Material(
      color: const Color(0xFF343A40),
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
                    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.red, size: 38),
          const SizedBox(height: 10),
          const Text('Unable to load data', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry', style: TextStyle(color: Color(0xFF90CA28)))),
        ],
      ),
    );
  }
}