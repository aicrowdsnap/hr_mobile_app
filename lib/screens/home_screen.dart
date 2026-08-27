import 'package:flutter/material.dart';

import '../models/attendance_status.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import 'attendance_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen> {
  final _attendanceService =
      AttendanceService();

  final _authService =
      AuthService();

  AttendanceStatus? _attendance;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _loadTodayStatus();
  }

  Future<void>
      _loadTodayStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result =
        await _attendanceService.getCurrentStatus();

      if (!mounted) return;

      setState(() {
        _attendance =
            AttendanceStatus.fromJson(
          result,
        );
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString()
            .replaceFirst(
              'Exception: ',
              '',
            );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    try {
      await _authService.logout();
    } catch (_) {}

    if (!mounted) return;

    Navigator.of(context)
        .pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            const LoginScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> _openAttendance() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const AttendanceScreen(),
      ),
    );

    await _loadTodayStatus();
  }

  String _getGreeting() {
    final hour =
        DateTime.now().hour;

    if (hour < 12) {
      return 'Good morning';
    }

    if (hour < 17) {
      return 'Good afternoon';
    }

    return 'Good evening';
  }

  String _todayDate() {
    final now = DateTime.now();

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor:
            Colors.transparent,
        elevation: 0,
        surfaceTintColor:
            Colors.transparent,
        title: const Text(
          'NovaHR',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _logout,
            tooltip: 'Logout',
            icon: const Icon(
              Icons.logout_rounded,
            ),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _loadTodayStatus,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding:
              const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            30,
          ),
          children: [
            Text(
              _getGreeting(),
              style: TextStyle(
                color:
                    Colors.grey.shade600,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              'Employee Dashboard',
              style: TextStyle(
                fontSize: 27,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              _todayDate(),
              style: TextStyle(
                color:
                    Colors.grey.shade600,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 25),

            if (_loading)
              const Center(
                child: Padding(
                  padding:
                      EdgeInsets.all(40),
                  child:
                      CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              _ErrorCard(
                message: _error!,
                onRetry:
                    _loadTodayStatus,
              )
            else
              AttendanceStatusCard(
                attendance: _attendance,
              ),

            const SizedBox(height: 20),

            _QuickActionCard(
              icon: Icons.access_time_rounded,
              title: 'Attendance',
              subtitle:
                  'Clock in or clock out',
              onTap:
                  _openAttendance,
            ),

            const SizedBox(height: 14),

            const _InfoCard(),
          ],
        ),
      ),
    );
  }
}

class AttendanceStatusCard
    extends StatelessWidget {
  final AttendanceStatus? attendance;

  const AttendanceStatusCard({
    super.key,
    required this.attendance,
  });

  String _formatTime(String? value) {
    if (value == null ||
        value.trim().isEmpty) {
      return '--';
    }

    try {
      final dateTime =
          DateTime.parse(value).toLocal();

      final hour =
          dateTime.hour == 0
              ? 12
              : dateTime.hour > 12
                  ? dateTime.hour - 12
                  : dateTime.hour;

      final minute =
          dateTime.minute
              .toString()
              .padLeft(2, '0');

      final period =
          dateTime.hour >= 12
              ? 'PM'
              : 'AM';

      return '$hour:$minute $period';
    } catch (_) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIn =
        attendance?.isClockedIn ?? false;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isIn
              ? [
                  Colors.blue.shade700,
                  Colors.blue.shade500,
                ]
              : [
                  Colors.blueGrey.shade700,
                  Colors.blueGrey.shade500,
                ],
        ),
        borderRadius:
            BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue
                .withValues(alpha: 0.18),
            blurRadius: 20,
            offset:
                const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.access_time_filled,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Today's Attendance",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white
                      .withValues(alpha: 0.18),
                  borderRadius:
                      BorderRadius.circular(30),
                ),
                child: Text(
                  isIn
                      ? 'CLOCKED IN'
                      : 'CLOCKED OUT',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: _HomeTime(
                  title: 'Clock In',
                  time:
                      _formatTime(
                    attendance
                        ?.clockInTime,
                  ),
                ),
              ),

              Expanded(
                child: _HomeTime(
                  title: 'Clock Out',
                  time:
                      _formatTime(
                    attendance
                        ?.clockOutTime,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeTime
    extends StatelessWidget {
  final String title;
  final String time;

  const _HomeTime({
    required this.title,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white
                .withValues(alpha: 0.75),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          time,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius:
          BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(20),
        child: Padding(
          padding:
              const EdgeInsets.all(19),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration:
                    BoxDecoration(
                  color: Colors.blue
                      .withValues(
                    alpha: 0.1,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                child: Icon(
                  icon,
                  color: Colors.blue,
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color:
                            Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard
    extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.blue
            .withValues(alpha: 0.06),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.blue
              .withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.blue.shade700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pull down to refresh your attendance status.',
              style: TextStyle(
                color:
                    Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard
    extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.red
            .withValues(alpha: 0.06),
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: Colors.red,
            size: 38,
          ),
          const SizedBox(height: 10),
          const Text(
            'Unable to load attendance',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color:
                  Colors.grey.shade700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}