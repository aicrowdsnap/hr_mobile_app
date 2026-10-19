import '../models/attendance_status.dart';
import 'api_client.dart';

class TodayAttendanceSnapshot {
  final AttendanceStatus attendance;
  final Map<String, dynamic>? employee;
  final Map<String, dynamic>? todayRecord;
  final List<Map<String, dynamic>> todayShifts;

  const TodayAttendanceSnapshot({
    required this.attendance,
    required this.employee,
    required this.todayRecord,
    required this.todayShifts,
  });

  bool get isClockedIn => attendance.isClockedIn;

  bool get hasCompletedToday =>
      !isClockedIn &&
      (attendance.isCompleted || todayRecord?['clockOutTime'] != null);

  bool get hasShiftToday => todayShifts.isNotEmpty;

  bool get hasAttendanceToday =>
      isClockedIn || attendance.hasClockIn || todayRecord != null;

  Map<String, dynamic>? get primaryShiftAssignment =>
      todayShifts.isEmpty ? null : todayShifts.first;
}

class AttendanceService {
  final ApiClient _api = ApiClient();

  static const Duration _colomboOffset = Duration(hours: 5, minutes: 30);

  Future<Map<String, dynamic>> getCurrentStatus() async {
    final result = await _api.getTrpc('attendance.getCurrentStatus');
    if (result == null) return {'status': 'clocked_out'};
    return Map<String, dynamic>.from(result);
  }

  Future<List<dynamic>> getMyDailyShifts({
    required String startDate,
    required String endDate,
  }) async {
    final result = await _api.getTrpc(
      'orgSettings.getMyDailyShifts',
      {'startDate': startDate, 'endDate': endDate},
    );
    if (result == null) return [];
    return List<dynamic>.from(result);
  }

  Future<void> clockIn({
    String? shiftId,
    String? notes,
    String? ipAddress,
  }) async {
    await _api.postTrpc(
      'attendance.clockIn',
      {
        if (shiftId != null && shiftId.isNotEmpty) 'shiftId': shiftId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (ipAddress != null && ipAddress.isNotEmpty) 'ipAddress': ipAddress,
      },
    );
  }

  Future<void> clockOut({
    String? notes,
    String? ipAddress,
  }) async {
    await _api.postTrpc(
      'attendance.clockOut',
      {
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (ipAddress != null && ipAddress.isNotEmpty) 'ipAddress': ipAddress,
      },
    );
  }

  Future<void> startBreak() async {
    await _api.postTrpc('attendance.startBreak', {});
  }

  Future<void> endBreak() async {
    await _api.postTrpc('attendance.endBreak', {});
  }

  Future<List<dynamic>> getHolidays({required int year}) async {
    final result = await _api.getTrpc('holidays.getAll', {'year': year});
    if (result == null) return [];
    return List<dynamic>.from(result);
  }

  Future<List<dynamic>> getDailyAttendanceRecords({
    required String employeeId,
    required int year,
    required int month,
  }) async {
    final result = await _api.getTrpc(
      'attendance.getDailyAttendanceRecords',
      {'employeeId': employeeId, 'year': year, 'month': month},
    );
    if (result == null) return [];
    return List<dynamic>.from(result);
  }

  Future<List<dynamic>> getAttendanceHistory({
    String? startDate,
    String? endDate,
    String? employeeId,
    int? page,
    int? limit,
  }) async {
    final result = await _api.getTrpc(
      'attendance.getHistory',
      {
        if (employeeId != null && employeeId.isNotEmpty)
          'employeeId': employeeId,
        if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
        if (page != null) 'page': page,
        if (limit != null) 'limit': limit,
      },
    );

    if (result == null) return [];

    if (result is Map && result.containsKey('data')) {
      return List<dynamic>.from(result['data'] ?? []);
    }

    if (result is List) {
      return result;
    }

    return [];
  }

  Future<TodayAttendanceSnapshot> getTodaySnapshot() async {
    final currentStatus = await getCurrentStatus();
    final rawEmployee = currentStatus['employee'];
    final employee = rawEmployee is Map
        ? Map<String, dynamic>.from(rawEmployee)
        : null;
    final employeeId = employee?['id']?.toString();

    final activeStatus = AttendanceStatus.fromJson(currentStatus);

    if (employeeId == null || employeeId.isEmpty) {
      return TodayAttendanceSnapshot(
        attendance: activeStatus,
        employee: employee,
        todayRecord: null,
        todayShifts: const [],
      );
    }

    final now = _colomboNow();
    final todayKey = _dateKey(now);

    final startOfTodayUtc = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).subtract(_colomboOffset);
    final startOfTomorrowUtc = DateTime.utc(
      now.year,
      now.month,
      now.day + 1,
    ).subtract(_colomboOffset);

    final results = await Future.wait<dynamic>([
      getAttendanceHistory(
        employeeId: employeeId,
        page: 1,
        limit: 31,
      ),
      getMyDailyShifts(
        startDate: startOfTodayUtc.toIso8601String(),
        endDate: startOfTomorrowUtc.toIso8601String(),
      ),
    ]);

    final rawHistory = List<dynamic>.from(results[0] as List);
    final rawShifts = List<dynamic>.from(results[1] as List);

    Map<String, dynamic>? todayRecord;
    for (final item in rawHistory) {
      if (item is! Map) continue;
      final record = Map<String, dynamic>.from(item);
      if (_attendanceRecordDateKey(record) == todayKey) {
        todayRecord = record;
        break;
      }
    }

    final todayShifts = <Map<String, dynamic>>[];
    for (final item in rawShifts) {
      if (item is! Map) continue;
      final assignment = Map<String, dynamic>.from(item);
      if (_shiftDateKey(assignment['shiftDate']) == todayKey) {
        todayShifts.add(assignment);
      }
    }

    final recordStatus =
        todayRecord == null ? null : AttendanceStatus.fromJson(todayRecord);

    AttendanceStatus effectiveStatus;

    if (recordStatus?.isCompleted == true) {
      effectiveStatus = recordStatus!;
    } else if (activeStatus.isClockedIn) {
      effectiveStatus = activeStatus;
    } else if (recordStatus != null) {
      effectiveStatus = recordStatus;
    } else {
      effectiveStatus = activeStatus;
    }

    return TodayAttendanceSnapshot(
      attendance: effectiveStatus,
      employee: employee,
      todayRecord: todayRecord,
      todayShifts: todayShifts,
    );
  }

  static DateTime _colomboNow() =>
      DateTime.now().toUtc().add(_colomboOffset);

  static String _dateKey(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String? _attendanceRecordDateKey(Map<String, dynamic> record) {
    final raw = record['attendanceDate'] ?? record['clockInTime'];
    if (raw == null) return null;

    final value = raw.toString().trim();
    if (value.length >= 10) return value.substring(0, 10);
    return null;
  }

  static String? _shiftDateKey(dynamic rawValue) {
    if (rawValue == null) return null;

    final raw = rawValue.toString().trim();
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw.length >= 10 ? raw.substring(0, 10) : null;
    }

    final colombo = parsed.isUtc
        ? parsed.toUtc().add(_colomboOffset)
        : parsed;
    return _dateKey(colombo);
  }
}
