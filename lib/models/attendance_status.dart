class AttendanceStatus {
  final String status;
  final String? clockInTime;
  final String? clockOutTime;
  final String? date;
  final String? location;
  final int? totalWorkingMinutes;

  const AttendanceStatus({
    required this.status,
    this.clockInTime,
    this.clockOutTime,
    this.date,
    this.location,
    this.totalWorkingMinutes,
  });

  factory AttendanceStatus.fromJson(Map<String, dynamic> json) {
    final record = json['activeRecord'] as Map<String, dynamic>?;

    return AttendanceStatus(
      status: json['status']?.toString() ?? 'clocked_out',
      clockInTime: record?['clockInTime']?.toString() ?? json['clockInTime']?.toString(),
      clockOutTime: record?['clockOutTime']?.toString() ?? json['clockOutTime']?.toString(),
      date: record?['attendanceDate']?.toString() ?? json['date']?.toString(),
      location: record?['locationClockIn']?.toString() ?? json['location']?.toString(),
      totalWorkingMinutes: record?['totalWorkingMinutes'] ?? json['totalWorkingMinutes'],
    );
  }

  bool get isClockedIn => status == 'clocked_in';
  bool get isClockedOut => status == 'clocked_out';
}