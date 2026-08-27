import 'api_client.dart';

class AttendanceService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> getCurrentStatus() async {
    final result = await _api.getTrpc(
      'attendance.getCurrentStatus',
    );

    if (result == null) {
      return {
        'status': 'clocked_out',
      };
    }

    return Map<String, dynamic>.from(result);
  }

  // Fetch daily shifts for the employee (matches Next.js orgSettings.getMyDailyShifts)
  Future<List<dynamic>> getMyDailyShifts({
    required String startDate,
    required String endDate,
  }) async {
    final result = await _api.getTrpc(
      'orgSettings.getMyDailyShifts',
      {
        'startDate': startDate,
        'endDate': endDate,
      },
    );

    if (result == null) return [];
    return List<dynamic>.from(result);
  }

  Future<void> clockIn({
    required String shiftId,
    String? notes,
    String? ipAddress,
  }) async {
    await _api.postTrpc(
      'attendance.clockIn',
      {
        'shiftId': shiftId,
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
    await _api.postTrpc(
      'attendance.startBreak',
      {},
    );
  }

  Future<void> endBreak() async {
    await _api.postTrpc(
      'attendance.endBreak',
      {},
    );
  }
}