import 'api_client.dart';

class LeaveService {
  final ApiClient _api = ApiClient();

  Future<List<dynamic>> getAvailableLeaveTypes() async {
    final result = await _api.getTrpc('leave.getAvailableLeaveTypes');
    if (result == null) return [];
    return List<dynamic>.from(result);
  }

  Future<List<dynamic>> getBalances({String? employeeId}) async {
    final inputMap = <String, dynamic>{
      'employeeId': employeeId ?? '',
    };
    
    final result = await _api.getTrpc('leave.getBalances', inputMap);
    if (result == null) return [];
    return List<dynamic>.from(result);
  }

  Future<List<dynamic>> getLeaveRequests({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final input = <String, dynamic>{'page': page, 'limit': limit};
    if (status != null) input['status'] = status;
    final result = await _api.getTrpc('leave.list', input);
    if (result == null || result['data'] == null) return [];
    return List<dynamic>.from(result['data']);
  }

  Future<void> createLeaveRequest({
    required String leaveType,
    required String startDate,
    required String endDate,
    String? reason,
  }) async {
    await _api.postTrpc(
      'leave.create',
      {
        'leaveType': leaveType,
        'startDate': startDate,
        'endDate': endDate,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }
}