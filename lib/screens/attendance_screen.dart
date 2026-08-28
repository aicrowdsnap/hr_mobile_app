import 'package:flutter/material.dart';

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
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Load current attendance status (this now includes the assigned shift!)
      final statusResult = await _attendanceService.getCurrentStatus();
      final employeeData = statusResult['employee'] as Map<String, dynamic>?;
      final employeeId = employeeData?['id']?.toString();

      if (employeeId == null) {
        throw Exception("Could not find employee profile.");
      }

      // 2. Load monthly attendance history to check for today's record
      final now = DateTime.now();
      final history = await _attendanceService.getDailyAttendanceRecords(
        employeeId: employeeId,
        year: now.year,
        month: now.month,
      );

      if (!mounted) return;

      setState(() {
        _attendance = AttendanceStatus.fromJson(statusResult);
        
        // Extract the shift returned directly from getCurrentStatus
        final currentShift = employeeData?['currentShift'] as Map<String, dynamic>?;
        
        if (currentShift != null) {
          _shifts = [{'shift': currentShift}];
          _selectedShiftId = currentShift['id']?.toString();
        } else {
          _shifts = [];
          _selectedShiftId = null;
        }
        
        _todayRecord = null;
        // Find today's record manually from the monthly list
        for (var a in history) {
          if (a['attendanceDate'] != null) {
            final d = DateTime.parse(a['attendanceDate'].toString()).toLocal();
            if (d.year == now.year && d.month == now.month && d.day == now.day) {
              _todayRecord = a as Map<String, dynamic>;
              break;
            }
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _clockIn() async {
    if (_selectedShiftId == null || _selectedShiftId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a shift before clocking in'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await _performAttendanceAction(clockIn: true);
  }

  Future<void> _clockOut() async {
    await _performAttendanceAction(clockIn: false);
  }

  Future<void> _performAttendanceAction({required bool clockIn}) async {
    setState(() {
      _actionLoading = true;
    });

    try {
      if (clockIn) {
        await _attendanceService.clockIn(
          shiftId: _selectedShiftId!,
        );
      } else {
        await _attendanceService.clockOut();
      }

      await _loadData();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              clockIn ? 'Clock-in successful' : 'Clock-out successful',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green.shade700,
            margin: const EdgeInsets.all(16),
          ),
        );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
            margin: const EdgeInsets.all(16),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  String _formatTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '--';
    }

    try {
      final dateTime = DateTime.parse(value).toLocal();
      final hour = dateTime.hour == 0
          ? 12
          : dateTime.hour > 12
              ? dateTime.hour - 12
              : dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';

      return '$hour:$minute $period';
    } catch (_) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isClockedIn = _attendance?.isClockedIn ?? false;
    
    // Check if user already clocked out today
    final hasCompletedToday = !isClockedIn && _todayRecord != null && _todayRecord!['clockOutTime'] != null;

    // Use active attendance times if clocked in, otherwise use historical record times if they exist
    final displayClockIn = isClockedIn ? _attendance?.clockInTime : _todayRecord?['clockInTime']?.toString();
    final displayClockOut = isClockedIn ? _attendance?.clockOutTime : _todayRecord?['clockOutTime']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('Mark Attendance', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: hasCompletedToday
                          ? Colors.teal.withValues(alpha: 0.1)
                          : isClockedIn
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.blue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasCompletedToday
                          ? Icons.check_circle_rounded
                          : isClockedIn
                              ? Icons.how_to_reg_rounded
                              : Icons.access_time_rounded,
                      size: 48,
                      color: hasCompletedToday
                          ? Colors.teal
                          : isClockedIn
                              ? Colors.green
                              : Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    hasCompletedToday
                        ? 'Shift Completed'
                        : isClockedIn
                            ? 'You are currently clocked in'
                            : 'You are not clocked in',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasCompletedToday
                        ? 'You have already completed your shift for today.'
                        : isClockedIn
                            ? 'Your attendance is active for today.'
                            : 'Select your shift and clock in to start.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Shift Selection Dropdown (Hidden if shift is already completed)
                  if (!isClockedIn && !hasCompletedToday && !_loading) ...[
                    if (_shifts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.amber.shade800),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No shifts assigned for today. Please contact HR.',
                                style: TextStyle(
                                  color: Colors.amber.shade900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: _selectedShiftId,
                        decoration: InputDecoration(
                          labelText: 'Select Shift',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        items: _shifts.map((item) {
                          final shiftData = item as Map<String, dynamic>;
                          final shift = shiftData['shift'] as Map<String, dynamic>;
                          return DropdownMenuItem<String>(
                            value: shift['id'].toString(),
                            child: Text(
                              '${shift['name']} (${shift['startTime']} - ${shift['endTime']})',
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedShiftId = val;
                          });
                        },
                      ),
                    const SizedBox(height: 20),
                  ],

                  if (_loading)
                    const CircularProgressIndicator()
                  else if (_error != null)
                    Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade600,
                          size: 38,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  else
                    _Times(
                      clockIn: _formatTime(displayClockIn),
                      clockOut: _formatTime(displayClockOut),
                    ),
                  const SizedBox(height: 30),
                  
                  // Hide action button entirely if shift is completed today
                  if (!_loading && !hasCompletedToday)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _actionLoading || (!isClockedIn && _shifts.isEmpty)
                            ? null
                            : isClockedIn
                                ? _clockOut
                                : _clockIn,
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
                                isClockedIn
                                    ? Icons.logout_rounded
                                    : Icons.login_rounded,
                              ),
                        label: Text(
                          _actionLoading
                              ? 'Processing...'
                              : isClockedIn
                                  ? 'Clock Out'
                                  : 'Clock In',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isClockedIn
                              ? Colors.red.shade600
                              : Colors.green.shade600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
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
  final String clockIn;
  final String clockOut;

  const _Times({required this.clockIn, required this.clockOut});

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
        const SizedBox(width: 14),
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

  const _TimeBox({required this.icon, required this.title, required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(height: 7),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            time,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }
}