class AttendanceStatus {
  final String status;
  final String? clockInTime;
  final String? clockOutTime;
  final String? date;
  final String? location;

  const AttendanceStatus({
    required this.status,
    this.clockInTime,
    this.clockOutTime,
    this.date,
    this.location,
  });

  factory AttendanceStatus.fromJson(
    Map<String, dynamic> json,
  ) {
    return AttendanceStatus(
      status: json['status']?.toString() ?? 'clocked_out',
      clockInTime: json['clockInTime']?.toString(),
      clockOutTime: json['clockOutTime']?.toString(),
      date: json['date']?.toString(),
      location: json['location']?.toString(),
    );
  }

  bool get isClockedIn =>
      status == 'clocked_in';

  bool get isClockedOut =>
      status == 'clocked_out';
}