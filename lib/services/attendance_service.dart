import 'api_client.dart';

class AttendanceService {
  final ApiClient _api = ApiClient();

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
    String? ipAddress, // Format: "latitude,longitude"
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
    String? ipAddress, // Format: "latitude,longitude"
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
    required String startDate,
    required String endDate,
  }) async {
    final result = await _api.getTrpc(
      'attendance.getAttendanceHistory',
      {'startDate': startDate, 'endDate': endDate},
    );
    if (result == null) return [];
    return List<dynamic>.from(result['data'] ?? []);
  }
}