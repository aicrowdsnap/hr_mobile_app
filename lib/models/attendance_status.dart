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
    final rawRecord = json['activeRecord'];
    final record = rawRecord is Map
        ? Map<String, dynamic>.from(rawRecord)
        : <String, dynamic>{};

    return AttendanceStatus(
      status: _asString(record['status']) ??
          _asString(json['status']) ??
          'clocked_out',
      clockInTime:
          _asString(record['clockInTime']) ?? _asString(json['clockInTime']),
      clockOutTime:
          _asString(record['clockOutTime']) ?? _asString(json['clockOutTime']),
      date: _asString(record['attendanceDate']) ??
          _asString(json['attendanceDate']) ??
          _asString(json['date']),
      location: _asString(record['locationClockIn']) ??
          _asString(json['locationClockIn']) ??
          _asString(json['location']),
      totalWorkingMinutes: _asInt(record['totalWorkingMinutes']) ??
          _asInt(json['totalWorkingMinutes']),
    );
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  bool get isClockedIn =>
      clockOutTime == null &&
      (status == 'clocked_in' ||
          status == 'break_start' ||
          status == 'break_end');

  bool get isOnBreak => status == 'break_start' && clockOutTime == null;

  bool get isClockedOut =>
      status == 'clocked_out' || status == 'completed' || clockOutTime != null;

  bool get hasClockIn => clockInTime != null && clockInTime!.isNotEmpty;

  bool get hasClockOut => clockOutTime != null && clockOutTime!.isNotEmpty;

  bool get isCompleted => hasClockIn && hasClockOut;
}
