import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../services/attendance_service.dart';
import '../theme/app_colors.dart';

class MyCalendarScreen extends StatefulWidget {
  const MyCalendarScreen({super.key});

  @override
  State<MyCalendarScreen> createState() => _MyCalendarScreenState();
}

class _MyCalendarScreenState extends State<MyCalendarScreen> {
  final AttendanceService _service = AttendanceService();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoading = false;

  Map<String, dynamic> _shiftsMap = {};
  Map<String, dynamic> _holidaysMap = {};
  Map<String, dynamic> _attendanceMap = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadMonthData(_focusedDay);
  }

  String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Future<void> _loadMonthData(DateTime date) async {
    setState(() => _isLoading = true);
    try {
      final year = date.year;
      final month = date.month;
      
      final startDate = DateTime.utc(year, month, 1).subtract(const Duration(hours: 5, minutes: 30));
      final endDate = DateTime.utc(year, month + 1, 1).subtract(const Duration(hours: 5, minutes: 30));

      final statusResult = await _service.getCurrentStatus();
      final employeeId = statusResult['employee']?['id']?.toString();
      if (employeeId == null) throw Exception("Could not find employee ID.");

      final results = await Future.wait([
        _service.getHolidays(year: year),
        _service.getDailyAttendanceRecords(employeeId: employeeId, year: year, month: month),
        _service.getMyDailyShifts(startDate: startDate.toIso8601String(), endDate: endDate.toIso8601String()),
      ]);

      if (!mounted) return;

      final newHolidaysMap = <String, dynamic>{};
      for (var h in results[0]) {
        if (h['date'] != null) {
          final localDate = DateTime.parse(h['date']).toLocal();
          final dateStr = DateFormat('yyyy-MM-dd').format(localDate);
          newHolidaysMap[dateStr] = h;
        }
      }

      final newAttendanceMap = <String, dynamic>{};
      for (var a in results[1]) {
        if (a['attendanceDate'] != null) {
          final localDate = DateTime.parse(a['attendanceDate']).toLocal();
          final dateStr = DateFormat('yyyy-MM-dd').format(localDate);
          newAttendanceMap[dateStr] = a;
        }
      }

      final newShiftsMap = <String, dynamic>{};
      for (var s in results[2]) {
        if (s['shiftDate'] != null) {
          final localDate = DateTime.parse(s['shiftDate']).toLocal();
          final dateStr = DateFormat('yyyy-MM-dd').format(localDate);
          newShiftsMap[dateStr] = s['shift'];
        }
      }

      setState(() {
        _holidaysMap = newHolidaysMap;
        _attendanceMap = newAttendanceMap;
        _shiftsMap = newShiftsMap;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load calendar data: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildMarker(Color color) {
    return Container(
      width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedKey = _selectedDay != null ? _dateKey(_selectedDay!) : '';
    final dayShift = _shiftsMap[selectedKey];
    final dayHoliday = _holidaysMap[selectedKey];
    final dayAttendance = _attendanceMap[selectedKey];

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(title: const Text('My Schedule & History')),
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
              availableCalendarFormats: const {CalendarFormat.month: 'Month'},
              onDaySelected: (selectedDay, focusedDay) => setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; }),
              onPageChanged: (focusedDay) { _focusedDay = focusedDay; _loadMonthData(focusedDay); },
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  final key = _dateKey(date);
                  final markers = <Widget>[];
                  if (_holidaysMap.containsKey(key)) markers.add(_buildMarker(AppColors.warning));
                  if (_shiftsMap.containsKey(key)) markers.add(_buildMarker(AppColors.skyBlue));
                  if (_attendanceMap.containsKey(key)) {
                    final status = _attendanceMap[key]['status'];
                    if (status == 'present') markers.add(_buildMarker(AppColors.primaryCyan));
                    else if (status == 'absent') markers.add(_buildMarker(AppColors.error));
                    else if (status == 'on_leave') markers.add(_buildMarker(AppColors.purple));
                  }
                  if (markers.isEmpty) return const SizedBox();
                  return Positioned(bottom: 6, child: Row(mainAxisSize: MainAxisSize.min, children: markers));
                },
              ),
              headerStyle: HeaderStyle(
                titleTextStyle: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontSize: 17),
                formatButtonTextStyle: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                formatButtonDecoration: BoxDecoration(border: Border.fromBorderSide(BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)), borderRadius: const BorderRadius.all(Radius.circular(12))),
                leftChevronIcon: Icon(Icons.chevron_left, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                rightChevronIcon: Icon(Icons.chevron_right, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                weekendStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                weekendTextStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                outsideTextStyle: TextStyle(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                todayDecoration: BoxDecoration(color: isDark ? AppColors.darkSurfaceHighlight : AppColors.lightSurfaceHighlight, shape: BoxShape.circle),
                todayTextStyle: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                selectedDecoration: const BoxDecoration(color: AppColors.primaryCyan, shape: BoxShape.circle),
                selectedTextStyle: const TextStyle(color: AppColors.darkBackground, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primaryCyan)))
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    _selectedDay != null ? DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!) : 'Select a date',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                  ),
                  const SizedBox(height: 16),
                  if (dayHoliday != null)
                    _DetailCard(icon: Icons.celebration, iconColor: AppColors.warning, title: 'Holiday: ${dayHoliday['name']}', subtitle: dayHoliday['description'] ?? 'Company Holiday', bgColor: AppColors.warning.withValues(alpha: 0.1)),
                  if (dayShift != null)
                    _DetailCard(icon: Icons.work_history_rounded, iconColor: AppColors.skyBlue, title: 'Assigned Shift: ${dayShift['name']}', subtitle: '${dayShift['startTime']} - ${dayShift['endTime']}', bgColor: AppColors.skyBlue.withValues(alpha: 0.1))
                  else if (dayHoliday == null)
                    _DetailCard(icon: Icons.bedtime_rounded, iconColor: isDark ? AppColors.darkIcon : AppColors.lightIcon, title: 'No Shift Assigned', subtitle: 'Rest day or pending assignment', bgColor: isDark ? AppColors.darkSurface : AppColors.lightSurface),
                  if (dayAttendance != null)
                    _DetailCard(icon: _getAttendanceIcon(dayAttendance['status']), iconColor: _getAttendanceColor(dayAttendance['status']), title: 'Attendance: ${_formatStatus(dayAttendance['status'])}', subtitle: dayAttendance['notes'] ?? 'Record logged', bgColor: isDark ? AppColors.darkSurface : AppColors.lightSurface),
                ],
              ),
            ),
        ],
      ),
    );
  }

  IconData _getAttendanceIcon(String status) {
    switch (status) {
      case 'present': return Icons.check_circle_rounded;
      case 'absent': return Icons.cancel_rounded;
      case 'on_leave': return Icons.flight_takeoff_rounded;
      default: return Icons.info_rounded;
    }
  }

  Color _getAttendanceColor(String status) {
    switch (status) {
      case 'present': return AppColors.primaryCyan;
      case 'absent': return AppColors.error;
      case 'on_leave': return AppColors.purple;
      default: return AppColors.lightIcon;
    }
  }

  String _formatStatus(String status) => status.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
}

class _DetailCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor, bgColor;
  final String title, subtitle;
  const _DetailCard({required this.icon, required this.iconColor, required this.title, required this.subtitle, required this.bgColor});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: isDark ? AppColors.darkSurfaceHighlight : AppColors.lightSurfaceHighlight, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}