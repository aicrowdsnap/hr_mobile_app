import 'package:flutter/material.dart';

import '../models/attendance_status.dart';

class AttendanceStatusCard extends StatelessWidget {
  final AttendanceStatus? attendance;

  const AttendanceStatusCard({
    super.key,
    required this.attendance,
  });

  String _formatTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '--';
    }

    try {
      DateTime dateTime = DateTime.parse(value);
      dateTime = dateTime.toLocal().subtract(const Duration(hours: 5, minutes: 30));

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
    final isClockedIn = attendance?.isClockedIn ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF343A40),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isClockedIn
                      ? const Color(0xFF90CA28).withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  isClockedIn ? Icons.login_rounded : Icons.schedule_rounded,
                  color: isClockedIn ? const Color(0xFF90CA28) : Colors.orange,
                  size: 28,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isClockedIn ? 'Clocked In' : 'Not Clocked In',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isClockedIn
                      ? const Color(0xFF90CA28).withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  isClockedIn ? 'ACTIVE' : 'OFF',
                  style: TextStyle(
                    color: isClockedIn ? const Color(0xFF90CA28) : Colors.grey.shade300,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              Expanded(
                child: _TimeItem(
                  icon: Icons.login,
                  title: 'Clock In',
                  value: _formatTime(attendance?.clockInTime),
                ),
              ),
              Container(
                height: 55,
                width: 1,
                color: Colors.grey.shade700,
              ),
              Expanded(
                child: _TimeItem(
                  icon: Icons.logout,
                  title: 'Clock Out',
                  value: _formatTime(attendance?.clockOutTime),
                ),
              ),
            ],
          ),
          if (attendance?.location != null) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 19,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    attendance!.location!,
                    style: TextStyle(
                      color: Colors.grey.shade300,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _TimeItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Icon(
            icon,
            size: 21,
            color: Colors.blue.shade400,
          ),
          const SizedBox(height: 7),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}