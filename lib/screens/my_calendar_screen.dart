// lib/screens/my_calendar_screen.dart
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

  // Data maps keyed by date string (yyyy-MM-dd)
  Map<String, dynamic> _shiftsMap = {};
  Map<String, dynamic> _holidaysMap = {};
  Map<String, dynamic> _attendanceMap = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadMonthData(_focusedDay);
  }

  String _dateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Future<void> _loadMonthData(DateTime date) async {
    setState(() => _isLoading = true);

    try {
      final year = date.year;
      final month = date.month;

      // Calculate start and end of the month for shift queries
      final startDate = DateTime.utc(year, month, 1);
      final endDate = DateTime.utc(year, month + 1, 0, 23, 59, 59);

      // We need the employee ID first
      final statusResult = await _service.getCurrentStatus();
      final employeeId = statusResult['employee']?['id']?.toString();

      if (employeeId == null) {
        throw Exception("Could not find employee ID.");
      }

      // Fetch all three data sources concurrently
      final results = await Future.wait([
        _service.getHolidays(year: year),
        _service.getDailyAttendanceRecords(
          employeeId: employeeId, 
          year: year, 
          month: month
        ),
        _service.getMyDailyShifts(
          startDate: startDate.toIso8601String(),
          endDate: endDate.toIso8601String(),
        ),
      ]);

      final holidays = results[0];
      final attendance = results[1];
      final shifts = results[2];

      if (!mounted) return;

      // Map data by date string for O(1) calendar lookups
      final newHolidaysMap = <String, dynamic>{};
      for (var h in holidays) {
        if (h['date'] != null) {
          final d = DateTime.parse(h['date'].toString()).toLocal();
          newHolidaysMap[_dateKey(d)] = h;
        }
      }

      final newAttendanceMap = <String, dynamic>{};
      for (var a in attendance) {
        if (a['attendanceDate'] != null) {
          final d = DateTime.parse(a['attendanceDate'].toString()).toLocal();
          newAttendanceMap[_dateKey(d)] = a;
        }
      }

      final newShiftsMap = <String, dynamic>{};
      for (var s in shifts) {
        if (s['shiftDate'] != null) {
          final d = DateTime.parse(s['shiftDate'].toString()).toLocal();
          newShiftsMap[_dateKey(d)] = s['shift'];
        }
      }

      setState(() {
        _holidaysMap = newHolidaysMap;
        _attendanceMap = newAttendanceMap;
        _shiftsMap = newShiftsMap;
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
    final selectedKey = _selectedDay != null ? _dateKey(_selectedDay!) : '';
    final dayShift = _shiftsMap[selectedKey];
    final dayHoliday = _holidaysMap[selectedKey];
    final dayAttendance = _attendanceMap[selectedKey];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('My Schedule & History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {CalendarFormat.month: 'Month'},
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                _loadMonthData(focusedDay);
              },
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  final key = _dateKey(date);
                  final markers = <Widget>[];

                  if (_holidaysMap.containsKey(key)) {
                    markers.add(_buildMarker(Colors.amber.shade700));
                  }
                  if (_shiftsMap.containsKey(key)) {
                    markers.add(_buildMarker(Colors.blue.shade600));
                  }
                  if (_attendanceMap.containsKey(key)) {
                    final status = _attendanceMap[key]['status'];
                    if (status == 'present') {
                      markers.add(_buildMarker(Colors.green.shade600));
                    } else if (status == 'absent') {
                      markers.add(_buildMarker(Colors.red.shade600));
                    } else if (status == 'on_leave') {
                      markers.add(_buildMarker(Colors.purple.shade600));
                    }
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
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(color: Colors.blue.shade900),
                selectedDecoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    _selectedDay != null
                        ? DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!)
                        : 'Select a date',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1. Holiday Section
                  if (dayHoliday != null)
                    _DetailCard(
                      icon: Icons.celebration,
                      iconColor: Colors.amber.shade600,
                      title: 'Holiday: ${dayHoliday['name']}',
                      subtitle: dayHoliday['description'] ?? 'Company Holiday',
                      bgColor: Colors.amber.shade50,
                    ),

                  // 2. Shift Section
                  if (dayShift != null)
                    _DetailCard(
                      icon: Icons.work_history_rounded,
                      iconColor: Colors.blue.shade600,
                      title: 'Assigned Shift: ${dayShift['name']}',
                      subtitle: '${dayShift['startTime']} - ${dayShift['endTime']}',
                      bgColor: Colors.blue.shade50,
                    )
                  else if (dayHoliday == null)
                    const _DetailCard(
                      icon: Icons.bedtime_rounded,
                      iconColor: Colors.grey,
                      title: 'No Shift Assigned',
                      subtitle: 'Rest day or pending assignment',
                      bgColor: Colors.white,
                    ),

                  // 3. Attendance Section
                  if (dayAttendance != null)
                    _DetailCard(
                      icon: _getAttendanceIcon(dayAttendance['status']),
                      iconColor: _getAttendanceColor(dayAttendance['status']),
                      title: 'Attendance: ${_formatStatus(dayAttendance['status'])}',
                      subtitle: dayAttendance['notes'] ?? 'Record logged',
                      bgColor: Colors.white,
                    ),
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
      case 'present': return Colors.green.shade600;
      case 'absent': return Colors.red.shade600;
      case 'on_leave': return Colors.purple.shade600;
      default: return Colors.grey.shade600;
    }
  }

  String _formatStatus(String status) {
    return status.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }
}

class _DetailCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color bgColor;

  const _DetailCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                )
              ],
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}