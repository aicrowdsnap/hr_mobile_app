import 'package:flutter/material.dart';
import '../models/attendance_status.dart';
import '../theme/app_colors.dart';

class AttendanceStatusCard extends StatelessWidget {
  final AttendanceStatus? attendance;
  final bool hasShiftAssigned;
  final bool hasCompletedToday;

  const AttendanceStatusCard({
    super.key,
    required this.attendance,
    required this.hasShiftAssigned,
    required this.hasCompletedToday,
  });

  String _formatTime(String? value) {
    if (value == null || value.trim().isEmpty) return '--';
    try {
      final cleanValue = value.replaceAll('Z', '').replaceAll('z', '');
      DateTime dateTime = DateTime.parse(cleanValue).toLocal();
      final hour = dateTime.hour == 0 ? 12 : dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } catch (_) {
      return value;
    }
  }

  String _formatWorkingHours() {
    int totalMins = attendance?.totalWorkingMinutes ?? 0;
    final isClockedIn = attendance?.isClockedIn ?? false;

    if (isClockedIn && attendance?.clockInTime != null) {
      try {
        final cleanTime = attendance!.clockInTime!.replaceAll('Z', '').replaceAll('z', '');
        final clockInTime = DateTime.parse(cleanTime).toLocal();
        totalMins = DateTime.now().difference(clockInTime).inMinutes;
      } catch (_) {}
    }

    if (totalMins <= 0) return '--';
    final hours = totalMins ~/ 60;
    final mins = totalMins % 60;
    if (hours == 0) return '${mins}m';
    return '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isClockedIn = attendance?.isClockedIn ?? false;

    // Determine UI Configuration based on exact state
    Color cardColor;
    Color iconColor;
    IconData statusIcon;
    String statusTitle;
    String statusBadge;

    if (hasCompletedToday) {
      cardColor = AppColors.success;
      iconColor = AppColors.success;
      statusIcon = Icons.task_alt_rounded;
      statusTitle = "Shift Completed";
      statusBadge = "COMPLETED";
    } else if (isClockedIn) {
      cardColor = AppColors.primaryCyan;
      iconColor = AppColors.primaryCyan;
      statusIcon = Icons.access_time_filled;
      statusTitle = "Active Shift";
      statusBadge = "CLOCKED IN";
    } else if (hasShiftAssigned) {
      cardColor = Colors.orange;
      iconColor = Colors.orange;
      statusIcon = Icons.schedule_rounded;
      statusTitle = "Pending Clock In";
      statusBadge = "ACTION REQUIRED";
    } else {
      cardColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
      iconColor = isDark ? AppColors.darkIcon : AppColors.lightIcon;
      statusIcon = Icons.event_busy_rounded;
      statusTitle = "No Shift Assigned";
      statusBadge = "OFF";
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceHighlight : AppColors.lightSurfaceHighlight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  statusTitle,
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  statusBadge,
                  style: TextStyle(
                    color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _HomeTime(
                  title: 'Clock In',
                  time: _formatTime(attendance?.clockInTime),
                  isDark: isDark,
                ),
              ),
              Expanded(
                child: _HomeTime(
                  title: 'Clock Out',
                  time: _formatTime(attendance?.clockOutTime),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isClockedIn ? 'Active Worked Time:' : 'Total Worked Time:',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                _formatWorkingHours(),
                style: TextStyle(
                  color: iconColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
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