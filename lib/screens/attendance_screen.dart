import 'dart:async';

import 'package:flutter/material.dart';

import '../models/attendance_status.dart';
import '../services/attendance_service.dart';
import '../theme/app_colors.dart';
import 'package:geolocator/geolocator.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with WidgetsBindingObserver {
  final AttendanceService _attendanceService = AttendanceService();

  TodayAttendanceSnapshot? _snapshot;
  bool _loading = true;
  bool _backgroundSyncing = false;
  bool _actionLoading = false;
  String? _error;
  String? _selectedShiftId;
  Timer? _syncTimer;

  static const Duration _colomboOffset =
      Duration(hours: 5, minutes: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();

    _syncTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _loadData(silent: true);
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
      _loadData(silent: true);
    }
  }

Future<Map<String, dynamic>> _getDeviceLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Device GPS is turned off. Please enable location services.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied. Please allow access to clock in.');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied. Please enable them in app settings.');
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    double accuracy = position.accuracy;
    if (accuracy <= 0) accuracy = 50.0;

    if (accuracy > 200) {
      throw Exception('GPS signal is too weak (Accuracy: ${accuracy.round()}m). Please move outside for a better signal.');
    }

    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracyMeters': accuracy,
      'locationSource': 'device_gps',
      'deviceInfo': 'hr app',
    };
  }

  Future<void> _loadData({bool silent = false, bool force = false}) async {
    if (!force &&
        silent &&
        (_backgroundSyncing || _loading || _actionLoading)) {
      return;
    }

    if (silent) {
      if (!mounted) return;
      setState(() => _backgroundSyncing = true);
    } else if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final snapshot = await _attendanceService.getTodaySnapshot();

      if (!mounted) return;

      final availableShiftIds = snapshot.todayShifts
          .map(_shiftFromAssignment)
          .whereType<Map<String, dynamic>>()
          .map((shift) => shift['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      String? nextSelectedShiftId = _selectedShiftId;
      if (availableShiftIds.isEmpty) {
        nextSelectedShiftId = null;
      } else if (nextSelectedShiftId == null ||
          !availableShiftIds.contains(nextSelectedShiftId)) {
        nextSelectedShiftId = availableShiftIds.first;
      }

      setState(() {
        _snapshot = snapshot;
        _selectedShiftId = nextSelectedShiftId;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      if (!silent || _snapshot == null) {
        setState(() => _error = _cleanErrorMessage(e));
      }
    } finally {
      if (mounted) {
        if (silent) {
          setState(() => _backgroundSyncing = false);
        } else {
          _backgroundSyncing = false;
          setState(() => _loading = false);
        }
      } else {
        _backgroundSyncing = false;
      }
    }
  }

  Future<void> _clockIn() async {
    final snapshot = _snapshot;

    if (snapshot == null || !snapshot.hasShiftToday) {
      _showMessage(
        'No shift is assigned to you for today. Please contact HR.',
        isError: true,
      );
      return;
    }

    if (snapshot.hasAttendanceToday) {
      _showMessage(
        'An attendance record already exists for today.',
        isError: true,
      );
      await _loadData(silent: true, force: true);
      return;
    }

    if (_selectedShiftId == null || _selectedShiftId!.isEmpty) {
      _showMessage(
        'Please select a shift before clocking in.',
        isError: true,
      );
      return;
    }

    await _performAttendanceAction(clockIn: true);
  }

  Future<void> _clockOut() async {
    if (_snapshot?.isClockedIn != true) {
      _showMessage(
        'No active clock-in record was found.',
        isError: true,
      );
      await _loadData(silent: true, force: true);
      return;
    }

    await _performAttendanceAction(clockIn: false);
  }

  Future<void> _endBreak() async {
    if (_actionLoading) return;

    setState(() => _actionLoading = true);

    try {
      await _attendanceService.endBreak();
      await _loadData(silent: true, force: true);

      if (!mounted) return;
      _showMessage('Break ended. Attendance is active again.');
    } catch (e) {
      if (!mounted) return;
      await _loadData(silent: true, force: true);

      if (!mounted) return;
      _showMessage(_cleanErrorMessage(e), isError: true);
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  Future<void> _performAttendanceAction({required bool clockIn}) async {
    if (_actionLoading) return;

    setState(() => _actionLoading = true);

    try {
      final locationData = await _getDeviceLocation();

      if (clockIn) {
        await _attendanceService.clockIn(
          shiftId: _selectedShiftId,
          location: locationData,
        );
      } else {
        await _attendanceService.clockOut(
          location: locationData,
        );
      }

      await _loadData(silent: true, force: true);

      if (!mounted) return;
      _showMessage(
        clockIn ? 'Clock-in successful.' : 'Clock-out successful.',
      );
    } catch (e) {
      if (!mounted) return;

      await _loadData(silent: true, force: true);

      if (!mounted) return;
      _showMessage(_cleanErrorMessage(e), isError: true);
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  String _cleanErrorMessage(Object error) {
    var message = error.toString().trim();

    if (message.startsWith('ApiException:')) {
      message = message.substring('ApiException:'.length).trim();
    }
    if (message.startsWith('Exception:')) {
      message = message.substring('Exception:'.length).trim();
    }

    // The hosted API already reports shift validation time in Asia/Colombo.
    // Do not add another +05:30 here.
    return message;
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: isError ? AppColors.error : AppColors.primaryCyan,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  Map<String, dynamic>? _shiftFromAssignment(
    Map<String, dynamic> assignment,
  ) {
    final rawShift = assignment['shift'];
    if (rawShift is Map) {
      return Map<String, dynamic>.from(rawShift);
    }
    return null;
  }

  Map<String, dynamic>? get _selectedShift {
    final snapshot = _snapshot;
    if (snapshot == null || _selectedShiftId == null) return null;

    for (final assignment in snapshot.todayShifts) {
      final shift = _shiftFromAssignment(assignment);
      if (shift?['id']?.toString() == _selectedShiftId) {
        return shift;
      }
    }

    return null;
  }

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

  String _formatWorkedTime(AttendanceStatus attendance) {
    int? totalMinutes = attendance.totalWorkingMinutes;

    if (attendance.isClockedIn && attendance.clockInTime != null) {
      final clockIn = _parseServerWallClock(attendance.clockInTime);
      if (clockIn != null) {
        totalMinutes = _colomboWallClockNow().difference(clockIn).inMinutes;
      }
    }

    if (totalMinutes == null || totalMinutes < 0) return '--';

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours == 0) return '$minutes mins';
    if (minutes == 0) return '$hours hrs';
    return '$hours hrs $minutes mins';
  }

  String _shiftLabel(Map<String, dynamic>? shift) {
    if (shift == null) return 'Assigned Shift';
    return shift['name']?.toString() ?? 'Assigned Shift';
  }

  String _shiftTime(Map<String, dynamic>? shift) {
    if (shift == null) return 'Time not available';

    final start = shift['startTime']?.toString();
    final end = shift['endTime']?.toString();

    if (start == null || end == null) return 'Time not available';
    return '$start - $end';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading && _snapshot == null) {
      return Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(title: const Text('Mark Attendance')),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryCyan),
        ),
      );
    }

    if (_error != null && _snapshot == null) {
      return Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(title: const Text('Mark Attendance')),
        body: RefreshIndicator(
          onRefresh: () => _loadData(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 100),
              _ErrorState(
                message: _error!,
                onRetry: () => _loadData(),
              ),
            ],
          ),
        ),
      );
    }

    final snapshot = _snapshot;
    final attendance = snapshot?.attendance ??
        const AttendanceStatus(status: 'clocked_out');

    final isClockedIn = snapshot?.isClockedIn ?? attendance.isClockedIn;
    final isOnBreak = attendance.isOnBreak;
    final hasCompletedToday = snapshot?.hasCompletedToday ?? false;
    final hasShiftAssigned = snapshot?.hasShiftToday ?? false;
    final hasAttendanceToday = snapshot?.hasAttendanceToday ?? false;

    final selectedShift = _selectedShift ??
        (snapshot?.primaryShiftAssignment == null
            ? null
            : _shiftFromAssignment(snapshot!.primaryShiftAssignment!));

    final canClockIn =
        hasShiftAssigned && !hasAttendanceToday && !hasCompletedToday;

    late final Color statusColor;
    late final IconData statusIcon;
    late final String title;
    late final String subtitle;
    late final String badge;

    if (hasCompletedToday) {
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle_rounded;
      title = 'Shift Completed';
      subtitle = 'You have completed today\'s attendance.';
      badge = 'COMPLETED';
    } else if (isOnBreak) {
      statusColor = AppColors.warning;
      statusIcon = Icons.coffee_rounded;
      title = 'Break In Progress';
      subtitle = 'Your attendance is active. End the break before clocking out.';
      badge = 'ON BREAK';
    } else if (isClockedIn) {
      statusColor = AppColors.primaryCyan;
      statusIcon = Icons.how_to_reg_rounded;
      title = 'Currently Clocked In';
      subtitle = 'Your attendance is active and work time is running.';
      badge = 'WORKING';
    } else if (hasShiftAssigned && !hasAttendanceToday) {
      statusColor = AppColors.warning;
      statusIcon = Icons.schedule_rounded;
      title = 'Shift Assigned';
      subtitle = 'You have not clocked in yet. Start when you are ready.';
      badge = 'READY';
    } else if (hasAttendanceToday) {
      statusColor = AppColors.info;
      statusIcon = Icons.info_outline_rounded;
      title = 'Attendance Recorded';
      subtitle = 'An attendance record already exists for today.';
      badge = 'RECORDED';
    } else {
      statusColor =
          isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
      statusIcon = Icons.event_busy_rounded;
      title = 'No Shift Assigned';
      subtitle = 'There is no shift assigned to you for today.';
      badge = 'NO SHIFT';
    }

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        actions: [
          if (_backgroundSyncing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryCyan,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadData(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface
                    : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      statusIcon,
                      size: 46,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (hasShiftAssigned) ...[
                    const SizedBox(height: 24),
                    _ShiftCard(
                      shiftName: _shiftLabel(selectedShift),
                      shiftTime: _shiftTime(selectedShift),
                      color: statusColor,
                    ),
                  ],
                  if (!isClockedIn &&
                      !hasCompletedToday &&
                      !hasAttendanceToday &&
                      (snapshot?.todayShifts.length ?? 0) > 1) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedShiftId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Select today\'s shift',
                        labelStyle: TextStyle(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                      ),
                      items: snapshot!.todayShifts.map((assignment) {
                        final shift = _shiftFromAssignment(assignment);
                        final id = shift?['id']?.toString() ?? '';
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(
                            '${_shiftLabel(shift)} (${_shiftTime(shift)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedShiftId = value);
                      },
                    ),
                  ],
                  if (!hasShiftAssigned &&
                      !isClockedIn &&
                      !hasCompletedToday) ...[
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.warning,
                            size: 21,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Clock in is unavailable because no shift is assigned for today. Please contact HR if you expected a shift.',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (isClockedIn || hasCompletedToday) ...[
                    const SizedBox(height: 24),
                    _Times(
                      clockIn: _formatTime(attendance.clockInTime),
                      clockOut: isClockedIn
                          ? 'Working'
                          : _formatTime(attendance.clockOutTime),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceHighlight
                            : AppColors.lightSurfaceHighlight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timelapse_rounded,
                            color: statusColor,
                            size: 21,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isOnBreak
                                  ? 'Elapsed Since Clock In'
                                  : isClockedIn
                                      ? 'Current Worked Time'
                                      : 'Total Worked Time',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            _formatWorkedTime(attendance),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (hasCompletedToday)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            color: AppColors.success,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Attendance completed for today',
                            style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _actionLoading
                            ? null
                            : isOnBreak
                                ? _endBreak
                                : isClockedIn
                                    ? _clockOut
                                    : canClockIn
                                        ? _clockIn
                                        : null,
                        icon: _actionLoading
                            ? const SizedBox(
                                width: 21,
                                height: 21,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                isOnBreak
                                    ? Icons.play_circle_outline_rounded
                                    : isClockedIn
                                        ? Icons.logout_rounded
                                        : hasShiftAssigned
                                            ? Icons.login_rounded
                                            : Icons.event_busy_rounded,
                              ),
                        label: Text(
                          _actionLoading
                              ? 'Processing...'
                              : isOnBreak
                                  ? 'End Break'
                                  : isClockedIn
                                      ? 'Clock Out'
                                      : hasShiftAssigned
                                          ? 'Clock In'
                                          : 'No Shift Assigned',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isOnBreak
                              ? AppColors.warning
                              : isClockedIn
                                  ? AppColors.error
                                  : AppColors.primaryCyan,
                          disabledBackgroundColor: isDark
                              ? AppColors.darkSurfaceHighlight
                              : AppColors.lightSurfaceHighlight,
                          foregroundColor: Colors.white,
                          disabledForegroundColor: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  final String shiftName;
  final String shiftTime;
  final Color color;

  const _ShiftCard({
    required this.shiftName,
    required this.shiftTime,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceHighlight
            : AppColors.lightSurfaceHighlight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.work_history_outlined,
              color: color,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shiftName,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  shiftTime,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Times extends StatelessWidget {
  final String clockIn;
  final String clockOut;

  const _Times({
    required this.clockIn,
    required this.clockOut,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TimeBox(
            icon: Icons.login_rounded,
            title: 'Clock In',
            time: clockIn,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TimeBox(
            icon: Icons.logout_rounded,
            title: 'Clock Out',
            time: clockOut,
          ),
        ),
      ],
    );
  }
}

class _TimeBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String time;

  const _TimeBox({
    required this.icon,
    required this.title,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceHighlight
            : AppColors.lightSurfaceHighlight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: AppColors.info,
            size: 20,
          ),
          const SizedBox(height: 7),
          Text(
            title,
            style: TextStyle(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            time,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            'Could not load attendance',
            style: TextStyle(
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
