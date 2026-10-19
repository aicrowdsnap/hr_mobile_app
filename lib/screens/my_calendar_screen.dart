import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../services/attendance_service.dart';
import '../theme/app_colors.dart';

class MyCalendarScreen extends StatefulWidget {
  const MyCalendarScreen({super.key});

  @override
  State<MyCalendarScreen> createState() => _MyCalendarScreenState();
}

class _MyCalendarScreenState extends State<MyCalendarScreen> {
  final AttendanceService _service = AttendanceService();

  static const Duration _colomboOffset = Duration(hours: 5, minutes: 30);

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoading = false;
  Timer? _timer;

  Map<String, dynamic> _shiftsMap = {};
  Map<String, dynamic> _holidaysMap = {};
  Map<String, dynamic> _attendanceMap = {};
  Map<String, dynamic> _attendanceHistoryMap = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadMonthData(_focusedDay);

    // Updates ongoing worked time while the employee is still clocked in.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted || _selectedDay == null) return;
      final record = _attendanceHistoryMap[_dateKey(_selectedDay!)];
      if (record != null && record['clockOutTime'] == null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  DateTime _colomboNow() => DateTime.now().toUtc().add(_colomboOffset);

  String? _datePrefix(dynamic value) {
    if (value == null) return null;
    final raw = value.toString();
    return raw.length >= 10 ? raw.substring(0, 10) : null;
  }

  String? _shiftDateKey(dynamic value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return _datePrefix(value);

    final colombo = parsed.isUtc
        ? parsed.toUtc().add(_colomboOffset)
        : parsed;
    return _dateKey(colombo);
  }

  Future<void> _loadMonthData(DateTime date) async {
    setState(() => _isLoading = true);

    try {
      final year = date.year;
      final month = date.month;
      final monthPrefix =
          '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

      final startDate =
          DateTime.utc(year, month, 1).subtract(_colomboOffset);
      final endDate =
          DateTime.utc(year, month + 1, 1).subtract(_colomboOffset);

      final statusResult = await _service.getCurrentStatus();
      final employeeId = statusResult['employee']?['id']?.toString();

      if (employeeId == null || employeeId.isEmpty) {
        throw Exception('Could not find employee ID.');
      }

      final results = await Future.wait([
        _service.getHolidays(year: year),
        _service.getDailyAttendanceRecords(
          employeeId: employeeId,
          year: year,
          month: month,
        ),
        _service.getMyDailyShifts(
          startDate: startDate.toIso8601String(),
          endDate: endDate.toIso8601String(),
        ),
        // Raw history contains the real clock-in, clock-out and worked times.
        _service.getAttendanceHistory(
          employeeId: employeeId,
          page: 1,
          limit: 1000,
        ),
      ]);

      if (!mounted) return;

      final newHolidaysMap = <String, dynamic>{};
      for (final item in results[0]) {
        if (item is! Map) continue;
        final dateKey = _datePrefix(item['date']);
        if (dateKey != null) newHolidaysMap[dateKey] = item;
      }

      final newAttendanceMap = <String, dynamic>{};
      for (final item in results[1]) {
        if (item is! Map) continue;
        final dateKey = _datePrefix(item['attendanceDate']);
        if (dateKey != null) newAttendanceMap[dateKey] = item;
      }

      final newShiftsMap = <String, dynamic>{};
      for (final item in results[2]) {
        if (item is! Map) continue;
        final dateKey = _shiftDateKey(item['shiftDate']);
        if (dateKey != null && item['shift'] != null) {
          newShiftsMap[dateKey] = item['shift'];
        }
      }

      final newAttendanceHistoryMap = <String, dynamic>{};
      for (final item in results[3]) {
        if (item is! Map) continue;

        // Hosted attendance timestamps already contain the +05:30 app offset,
        // so use the stored date prefix directly. Do not call toLocal().
        final dateKey = _datePrefix(
          item['attendanceDate'] ?? item['clockInTime'],
        );

        if (dateKey != null && dateKey.startsWith(monthPrefix)) {
          // History comes newest first, so keep the first record for the day.
          newAttendanceHistoryMap.putIfAbsent(dateKey, () => item);
        }
      }

      setState(() {
        _holidaysMap = newHolidaysMap;
        _attendanceMap = newAttendanceMap;
        _shiftsMap = newShiftsMap;
        _attendanceHistoryMap = newAttendanceHistoryMap;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load calendar data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildMarker(Color color) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedKey =
        _selectedDay != null ? _dateKey(_selectedDay!) : '';

    final dayShift = _shiftsMap[selectedKey];
    final dayHoliday = _holidaysMap[selectedKey];
    final dayAttendance = _attendanceMap[selectedKey];
    final dayHistory = _attendanceHistoryMap[selectedKey];

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('My Schedule & History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : () => _loadMonthData(_focusedDay),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {
                CalendarFormat.month: 'Month',
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                  _selectedDay = focusedDay;
                });
                _loadMonthData(focusedDay);
              },
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  final key = _dateKey(date);
                  final markers = <Widget>[];

                  if (_holidaysMap.containsKey(key)) {
                    markers.add(_buildMarker(AppColors.warning));
                  }

                  if (_shiftsMap.containsKey(key)) {
                    markers.add(_buildMarker(AppColors.skyBlue));
                  }

                  if (_attendanceMap.containsKey(key)) {
                    final status =
                        _attendanceMap[key]['status']?.toString() ?? '';
                    markers.add(_buildMarker(_getAttendanceColor(status)));
                  } else if (_attendanceHistoryMap.containsKey(key)) {
                    markers.add(_buildMarker(AppColors.primaryCyan));
                  }

                  if (markers.isEmpty) return const SizedBox();

                  return Positioned(
                    bottom: 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: markers,
                    ),
                  );
                },
              ),
              headerStyle: HeaderStyle(
                titleTextStyle: TextStyle(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                  fontSize: 17,
                ),
                formatButtonTextStyle: TextStyle(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
                formatButtonDecoration: BoxDecoration(
                  border: Border.fromBorderSide(
                    BorderSide(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
                weekendStyle: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: TextStyle(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
                weekendTextStyle: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
                outsideTextStyle: TextStyle(
                  color:
                      isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                todayDecoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceHighlight
                      : AppColors.lightSurfaceHighlight,
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
                selectedDecoration: const BoxDecoration(
                  color: AppColors.primaryCyan,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(
                  color: AppColors.darkBackground,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryCyan,
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primaryCyan,
                onRefresh: () => _loadMonthData(_focusedDay),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      _selectedDay != null
                          ? DateFormat('EEEE, MMMM d, yyyy')
                              .format(_selectedDay!)
                          : 'Select a date',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (dayHoliday != null)
                      _DetailCard(
                        icon: Icons.celebration,
                        iconColor: AppColors.warning,
                        title: 'Holiday: ${dayHoliday['name']}',
                        subtitle: dayHoliday['description'] ?? 'Company Holiday',
                        bgColor: AppColors.warning.withValues(alpha: 0.1),
                      ),

                    if (dayShift != null)
                      _DetailCard(
                        icon: Icons.work_history_rounded,
                        iconColor: AppColors.skyBlue,
                        title: 'Assigned Shift: ${dayShift['name']}',
                        subtitle:
                            '${_formatShiftTime(dayShift['startTime'])} - ${_formatShiftTime(dayShift['endTime'])}',
                        bgColor: AppColors.skyBlue.withValues(alpha: 0.1),
                      )
                    else if (dayHoliday == null)
                      _DetailCard(
                        icon: Icons.bedtime_rounded,
                        iconColor:
                            isDark ? AppColors.darkIcon : AppColors.lightIcon,
                        title: 'No Shift Assigned',
                        subtitle: 'Rest day or pending assignment',
                        bgColor: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                      ),

                    if (dayHistory != null)
                      _AttendanceHistoryCard(
                        status: dayAttendance?['status']?.toString() ??
                            dayHistory['status']?.toString() ??
                            'present',
                        clockIn: _formatAttendanceTime(
                          dayHistory['clockInTime'],
                        ),
                        clockOut: dayHistory['clockOutTime'] == null
                            ? 'Not yet'
                            : _formatAttendanceTime(
                                dayHistory['clockOutTime'],
                              ),
                        workedTime: _formatWorkedTime(
                          _calculateWorkedMinutes(dayHistory),
                          ongoing: dayHistory['clockOutTime'] == null,
                        ),
                        ongoing: dayHistory['clockOutTime'] == null,
                      )
                    else if (dayAttendance != null)
                      _DetailCard(
                        icon: _getAttendanceIcon(
                          dayAttendance['status']?.toString() ?? '',
                        ),
                        iconColor: _getAttendanceColor(
                          dayAttendance['status']?.toString() ?? '',
                        ),
                        title:
                            'Attendance: ${_formatStatus(dayAttendance['status']?.toString() ?? 'unknown')}',
                        subtitle: dayAttendance['notes'] ??
                            'No clock-in / clock-out record found',
                        bgColor: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                      )
                    else
                      _DetailCard(
                        icon: Icons.history_toggle_off_rounded,
                        iconColor:
                            isDark ? AppColors.darkIcon : AppColors.lightIcon,
                        title: 'No Attendance Record',
                        subtitle: 'No clock-in or clock-out recorded for this date',
                        bgColor: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatShiftTime(dynamic value) {
    if (value == null) return '--';
    final raw = value.toString();

    try {
      final parsed = DateFormat('HH:mm').parse(raw.substring(0, 5));
      return DateFormat('hh:mm a').format(parsed);
    } catch (_) {
      return raw;
    }
  }

  String _formatAttendanceTime(dynamic value) {
    if (value == null) return '--';

    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();

    // Do not call toLocal() here. The hosted project already stores attendance
    // timestamps with the +05:30 application offset applied.
    return DateFormat('hh:mm a').format(parsed);
  }

  int? _calculateWorkedMinutes(Map<dynamic, dynamic> record) {
    final stored = _asInt(record['totalWorkingMinutes']);
    if (stored != null) return stored < 0 ? 0 : stored;

    final clockIn = DateTime.tryParse(record['clockInTime']?.toString() ?? '');
    if (clockIn == null) return null;

    final clockOutRaw = record['clockOutTime']?.toString();
    final end = clockOutRaw != null && clockOutRaw.isNotEmpty
        ? DateTime.tryParse(clockOutRaw)
        : _colomboNow();

    if (end == null) return null;

    var minutes = end.difference(clockIn).inMinutes;
    minutes -= _asInt(record['totalBreakMinutes']) ?? 0;

    return minutes < 0 ? 0 : minutes;
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  String _formatWorkedTime(int? minutes, {required bool ongoing}) {
    if (minutes == null) return ongoing ? 'In progress' : '--';

    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final text = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

    return ongoing ? '$text (ongoing)' : text;
  }

  IconData _getAttendanceIcon(String status) {
    switch (status) {
      case 'present':
        return Icons.check_circle_rounded;
      case 'absent':
        return Icons.cancel_rounded;
      case 'on_leave':
        return Icons.flight_takeoff_rounded;
      case 'clocked_in':
        return Icons.login_rounded;
      case 'clocked_out':
        return Icons.task_alt_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Color _getAttendanceColor(String status) {
    switch (status) {
      case 'present':
      case 'clocked_in':
      case 'clocked_out':
        return AppColors.primaryCyan;
      case 'absent':
        return AppColors.error;
      case 'on_leave':
        return AppColors.purple;
      default:
        return AppColors.lightIcon;
    }
  }

  String _formatStatus(String status) {
    return status
        .split('_')
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.length > 1 ? word.substring(1) : ''}',
        )
        .join(' ');
  }
}

class _AttendanceHistoryCard extends StatelessWidget {
  final String status;
  final String clockIn;
  final String clockOut;
  final String workedTime;
  final bool ongoing;

  const _AttendanceHistoryCard({
    required this.status,
    required this.clockIn,
    required this.clockOut,
    required this.workedTime,
    required this.ongoing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryCyan.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  ongoing ? Icons.work_history_rounded : Icons.task_alt_rounded,
                  color: AppColors.primaryCyan,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance History',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ongoing ? 'Currently working' : _formatCardStatus(status),
                      style: const TextStyle(
                        color: AppColors.primaryCyan,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _AttendanceValue(
                  icon: Icons.login_rounded,
                  label: 'Clock In',
                  value: clockIn,
                  color: AppColors.primaryCyan,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AttendanceValue(
                  icon: Icons.logout_rounded,
                  label: 'Clock Out',
                  value: clockOut,
                  color: AppColors.skyBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _AttendanceValue(
            icon: Icons.timelapse_rounded,
            label: 'Worked Time',
            value: workedTime,
            color: AppColors.purple,
          ),
        ],
      ),
    );
  }

  String _formatCardStatus(String value) {
    if (value == 'present' || value == 'clocked_out') return 'Completed';
    if (value == 'absent') return 'Absent';
    if (value == 'on_leave') return 'On Leave';
    if (value == 'clocked_in') return 'Clocked In';
    return value;
  }
}

class _AttendanceValue extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _AttendanceValue({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceHighlight
            : AppColors.lightSurfaceHighlight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
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

class _DetailCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final String subtitle;

  const _DetailCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceHighlight
                  : AppColors.lightSurfaceHighlight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    fontSize: 13,
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
