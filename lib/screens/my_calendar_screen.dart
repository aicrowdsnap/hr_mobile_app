import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../services/attendance_service.dart';

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
      final startDate = DateTime.utc(year, month, 1);
      final endDate = DateTime.utc(year, month + 1, 0, 23, 59, 59);

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
          final dateStr = h['date'].toString().split('T')[0];
          newHolidaysMap[dateStr] = h;
        }
      }

      final newAttendanceMap = <String, dynamic>{};
      for (var a in results[1]) {
        if (a['attendanceDate'] != null) {
          final dateStr = a['attendanceDate'].toString().split('T')[0];
          newAttendanceMap[dateStr] = a;
        }
      }

      final newShiftsMap = <String, dynamic>{};
      for (var s in results[2]) {
        if (s['shiftDate'] != null) {
          final dateStr = s['shiftDate'].toString().split('T')[0];
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
    final selectedKey = _selectedDay != null ? _dateKey(_selectedDay!) : '';
    final dayShift = _shiftsMap[selectedKey];
    final dayHoliday = _holidaysMap[selectedKey];
    final dayAttendance = _attendanceMap[selectedKey];

    return Scaffold(
      backgroundColor: const Color(0xFF2A3036),
      appBar: AppBar(title: const Text('My Schedule & History')),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF343A40),
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
                  if (_holidaysMap.containsKey(key)) markers.add(_buildMarker(Colors.amber));
                  if (_shiftsMap.containsKey(key)) markers.add(_buildMarker(Colors.blue));
                  if (_attendanceMap.containsKey(key)) {
                    final status = _attendanceMap[key]['status'];
                    if (status == 'present') markers.add(_buildMarker(const Color(0xFF90CA28)));
                    else if (status == 'absent') markers.add(_buildMarker(Colors.red));
                    else if (status == 'on_leave') markers.add(_buildMarker(Colors.purple));
                  }
                  if (markers.isEmpty) return const SizedBox();
                  return Positioned(bottom: 6, child: Row(mainAxisSize: MainAxisSize.min, children: markers));
                },
              ),
              headerStyle: const HeaderStyle(
                titleTextStyle: TextStyle(color: Colors.white, fontSize: 17),
                formatButtonTextStyle: TextStyle(color: Colors.white),
                formatButtonDecoration: BoxDecoration(border: Border.fromBorderSide(BorderSide(color: Colors.white30)), borderRadius: BorderRadius.all(Radius.circular(12))),
                leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
                rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.white70),
                weekendStyle: TextStyle(color: Colors.white70),
              ),
              calendarStyle: const CalendarStyle(
                defaultTextStyle: TextStyle(color: Colors.white),
                weekendTextStyle: TextStyle(color: Colors.white70),
                outsideTextStyle: TextStyle(color: Colors.white30),
                todayDecoration: BoxDecoration(color: Color(0xFF1E2328), shape: BoxShape.circle),
                todayTextStyle: TextStyle(color: Colors.white),
                selectedDecoration: BoxDecoration(color: Color(0xFF90CA28), shape: BoxShape.circle),
                selectedTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF90CA28))))
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    _selectedDay != null ? DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!) : 'Select a date',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  if (dayHoliday != null)
                    _DetailCard(icon: Icons.celebration, iconColor: Colors.amber, title: 'Holiday: ${dayHoliday['name']}', subtitle: dayHoliday['description'] ?? 'Company Holiday', bgColor: Colors.amber.withValues(alpha: 0.1)),
                  if (dayShift != null)
                    _DetailCard(icon: Icons.work_history_rounded, iconColor: Colors.blue, title: 'Assigned Shift: ${dayShift['name']}', subtitle: '${dayShift['startTime']} - ${dayShift['endTime']}', bgColor: Colors.blue.withValues(alpha: 0.1))
                  else if (dayHoliday == null)
                    _DetailCard(icon: Icons.bedtime_rounded, iconColor: Colors.grey.shade400, title: 'No Shift Assigned', subtitle: 'Rest day or pending assignment', bgColor: const Color(0xFF343A40)),
                  if (dayAttendance != null)
                    _DetailCard(icon: _getAttendanceIcon(dayAttendance['status']), iconColor: _getAttendanceColor(dayAttendance['status']), title: 'Attendance: ${_formatStatus(dayAttendance['status'])}', subtitle: dayAttendance['notes'] ?? 'Record logged', bgColor: const Color(0xFF343A40)),
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
      case 'present': return const Color(0xFF90CA28);
      case 'absent': return Colors.red;
      case 'on_leave': return Colors.purple;
      default: return Colors.grey;
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: Color(0xFF1E2328), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}