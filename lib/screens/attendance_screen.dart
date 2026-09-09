import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/attendance_status.dart';
import '../services/attendance_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _attendanceService = AttendanceService();
  AttendanceStatus? _attendance;
  List<dynamic> _shifts = [];
  Map<String, dynamic>? _todayRecord;
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  String? _selectedShiftId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final statusResult = await _attendanceService.getCurrentStatus();
      final employeeData = statusResult['employee'] as Map<String, dynamic>?;
      final employeeId = employeeData?['id']?.toString();

      if (employeeId == null) throw Exception("Could not find employee profile.");

      final slNow = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
      final todayStr = DateFormat('yyyy-MM-dd').format(slNow);

      // Fetch the full month range (aligned to Sri Lanka time) just like MyCalendarScreen
      final startDate = DateTime.utc(slNow.year, slNow.month, 1).subtract(const Duration(hours: 5, minutes: 30));
      final endDate = DateTime.utc(slNow.year, slNow.month + 1, 1).subtract(const Duration(hours: 5, minutes: 30));

      final historyFuture = _attendanceService.getDailyAttendanceRecords(
        employeeId: employeeId, 
        year: slNow.year, 
        month: slNow.month,
      );
      
      final shiftsFuture = _attendanceService.getMyDailyShifts(
        startDate: startDate.toIso8601String(),
        endDate: endDate.toIso8601String(),
      );

      final results = await Future.wait([historyFuture, shiftsFuture]);
      final history = results[0] as List<dynamic>;
      final rawShifts = results[1] as List<dynamic>;

      // Map shifts by local date string to safely handle timestamp offsets
      final shiftsMap = <String, dynamic>{};
      for (var s in rawShifts) {
        if (s['shiftDate'] != null) {
          final localDate = DateTime.parse(s['shiftDate']).toLocal();
          final dateStr = DateFormat('yyyy-MM-dd').format(localDate);
          shiftsMap[dateStr] = s;
        }
      }

      // Extract today's shift from the map
      final todayShiftItem = shiftsMap[todayStr];
      final shiftsList = todayShiftItem != null ? [todayShiftItem] : [];

      if (!mounted) return;

      setState(() {
        _attendance = AttendanceStatus.fromJson(statusResult);
        _shifts = shiftsList;

        if (_shifts.isNotEmpty) {
          final shiftObj = _shifts[0]['shift'] as Map<String, dynamic>?;
          _selectedShiftId = shiftObj?['id']?.toString();
        } else {
          _selectedShiftId = null;
        }
        
        _todayRecord = null;
        for (var a in history) {
          if (a['attendanceDate'] != null) {
            final attendanceLocalDate = DateTime.parse(a['attendanceDate']).toLocal();
            final dateStr = DateFormat('yyyy-MM-dd').format(attendanceLocalDate);
            if (dateStr == todayStr) {
              _todayRecord = a as Map<String, dynamic>;
              break;
            }
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clockIn() async {
    if (_shifts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No shifts assigned for today. Cannot clock in.'), 
        backgroundColor: Colors.orange,
      ));
      return;
    }

    if (_selectedShiftId == null || _selectedShiftId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a shift before clocking in'), 
        backgroundColor: Colors.orange,
      ));
      return;
    }
    await _performAttendanceAction(clockIn: true);
  }

  Future<void> _clockOut() async {
    await _performAttendanceAction(clockIn: false);
  }

  Future<void> _performAttendanceAction({required bool clockIn}) async {
    setState(() => _actionLoading = true);
    try {
      if (clockIn) {
        // FIX: shiftId MUST be passed because backend Zod schema strictly requires it
        await _attendanceService.clockIn(shiftId: _selectedShiftId);
      } else {
        await _attendanceService.clockOut();
      }
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(clockIn ? 'Clock-in successful' : 'Clock-out successful', style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF90CA28),
          behavior: SnackBarBehavior.floating, 
          margin: const EdgeInsets.all(16),
        ));
    } catch (e) {
      if (!mounted) return;
      
      String errorMessage = e.toString();
      
      if (errorMessage.contains('Current time is')) {
        try {
          final RegExp timeRegex = RegExp(r'Current time is (\d{2}:\d{2}:\d{2})');
          final match = timeRegex.firstMatch(errorMessage);
          
          if (match != null) {
            final utcTimeStr = match.group(1)!;
            final now = DateTime.now();
            final utcDate = DateTime.parse('${now.toString().split(' ')[0]} $utcTimeStr');
            
            // Add 5 hours and 30 minutes (Sri Lanka offset) to correct the error message
            final localDate = utcDate.add(const Duration(hours: 5, minutes: 30));
            final localTimeStr = DateFormat('HH:mm:ss').format(localDate);
            
            errorMessage = errorMessage.replaceAll(utcTimeStr, '$localTimeStr (Local Time)');
          }
        } catch (_) {
        }
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(errorMessage, style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red.shade700, 
          behavior: SnackBarBehavior.floating, 
          margin: const EdgeInsets.all(16),
        ));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  String _formatWorkingHours() {
    int totalMins = _attendance?.totalWorkingMinutes ?? 0;
    
    if ((_attendance?.isClockedIn ?? false) && _attendance?.clockInTime != null) {
      try {
        final cleanTime = _attendance!.clockInTime!.replaceAll('Z', '').replaceAll('z', '');
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

  @override
  Widget build(BuildContext context) {
    final isClockedIn = _attendance?.isClockedIn ?? false;
    final hasCompletedToday = !isClockedIn && _todayRecord != null && _todayRecord!['clockOutTime'] != null;
    final displayClockIn = isClockedIn ? _attendance?.clockInTime : _todayRecord?['clockInTime']?.toString();
    final displayClockOut = isClockedIn ? _attendance?.clockOutTime : _todayRecord?['clockOutTime']?.toString();

    final bool canClockIn = _shifts.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF2A3036),
      appBar: AppBar(title: const Text('Mark Attendance')),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0xFF343A40), borderRadius: BorderRadius.circular(24)),
              child: Column(
                children: [
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      color: hasCompletedToday ? Colors.teal.withValues(alpha: 0.15) 
                           : isClockedIn ? const Color(0xFF90CA28).withValues(alpha: 0.15) 
                           : Colors.blue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasCompletedToday ? Icons.check_circle_rounded : isClockedIn ? Icons.how_to_reg_rounded : Icons.access_time_rounded,
                      size: 48, color: hasCompletedToday ? Colors.teal : isClockedIn ? const Color(0xFF90CA28) : Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    hasCompletedToday ? 'Shift Completed' : isClockedIn ? 'You are currently clocked in' : 'You are not clocked in',
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasCompletedToday ? 'You have already completed your shift for today.' : isClockedIn ? 'Your attendance is active for today.' : 'Select your shift and clock in to start.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  ),
                  const SizedBox(height: 28),
                  
                  if (!isClockedIn && !hasCompletedToday && !_loading) ...[
                    if (_shifts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1), 
                          borderRadius: BorderRadius.circular(14), 
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No shifts assigned to you for today. Please contact HR to assign a shift.', 
                                style: TextStyle(color: Colors.amber.shade200, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Theme(
                        data: Theme.of(context).copyWith(canvasColor: const Color(0xFF343A40)),
                        child: DropdownButtonFormField<String>(
                          value: _selectedShiftId,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Select Shift',
                            labelStyle: TextStyle(color: Colors.grey.shade400),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade700)),
                          ),
                          items: _shifts.map((item) {
                            final shift = item['shift'] as Map<String, dynamic>;
                            return DropdownMenuItem<String>(
                              value: shift['id'].toString(),
                              child: Text('${shift['name']} (${shift['startTime']} - ${shift['endTime']})', style: const TextStyle(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedShiftId = val),
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],

                  if (_loading) const CircularProgressIndicator(color: Color(0xFF90CA28))
                  else if (_error != null)
                    Column(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 38),
                        const SizedBox(height: 8),
                        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                      ],
                    )
                  else ...[
                    _Times(clockIn: _formatTime(displayClockIn), clockOut: _formatTime(displayClockOut)),
                    if (isClockedIn) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2328),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Active Worked Time:', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                            Text(_formatWorkingHours(), style: const TextStyle(color: Color(0xFF90CA28), fontSize: 15, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ],
                  
                  if (!_loading && !hasCompletedToday)
                  const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, height: 56,
                      child: ElevatedButton.icon(
                        // Disabled if loading, or if trying to clock in when no shifts are assigned
                        onPressed: _actionLoading || (!isClockedIn && !canClockIn) ? null : isClockedIn ? _clockOut : _clockIn,
                        icon: _actionLoading ? const SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Icon(isClockedIn ? Icons.logout_rounded : Icons.login_rounded),
                        label: Text(_actionLoading ? 'Processing...' : isClockedIn ? 'Clock Out' : 'Clock In', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isClockedIn ? Colors.red.shade600 : const Color(0xFF90CA28),
                          disabledBackgroundColor: Colors.grey.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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

class _Times extends StatelessWidget {
  final String clockIn, clockOut;
  const _Times({required this.clockIn, required this.clockOut});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _TimeBox(icon: Icons.login_rounded, title: 'Clock In', time: clockIn)),
        const SizedBox(width: 14),
        Expanded(child: _TimeBox(icon: Icons.logout_rounded, title: 'Clock Out', time: clockOut)),
      ],
    );
  }
}

class _TimeBox extends StatelessWidget {
  final IconData icon;
  final String title, time;
  const _TimeBox({required this.icon, required this.title, required this.time});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E2328), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Icon(icon, color: Colors.blue.shade400),
          const SizedBox(height: 7),
          Text(title, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          const SizedBox(height: 5),
          Text(time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white)),
        ],
      ),
    );
  }
}