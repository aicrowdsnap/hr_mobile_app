import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/leave_service.dart';
import '../theme/app_colors.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  final _leaveService = LeaveService();
  bool _loading = true;
  List<dynamic> _balances = [];
  List<dynamic> _availableTypes = [];
  List<dynamic> _requests = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLeaveData();
  }

  Future<void> _loadLeaveData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _leaveService.getBalances(),
        _leaveService.getAvailableLeaveTypes(),
        _leaveService.getLeaveRequests(),
      ]);

      if (!mounted) return;
      setState(() {
        _balances = results[0];
        _availableTypes = results[1];
        _requests = results[2];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showApplyDialog() {
    if (_availableTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No leave types available. Leave requests are disabled.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 24,
        ),
        child: _ApplyLeaveForm(
          availableTypes: _availableTypes,
          balances: _balances,
          onSuccess: () {
            Navigator.pop(context);
            _loadLeaveData();
          },
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'cancelled':
        return Colors.grey.shade400;
      case 'pending':
        return AppColors.warning;
      default:
        return Colors.grey;
    }
  }

  String _getLeaveTypeName(dynamic request) {
    if (request is! Map) return 'Leave Request';

    // 1. Prefer a name returned directly by the leave.list API.
    final directName = request['leaveTypeName']?.toString().trim();
    if (directName != null && directName.isNotEmpty) {
      return directName;
    }

    // 2. Support APIs that return leaveType as an object.
    final rawLeaveType = request['leaveType'];
    if (rawLeaveType is Map) {
      final nestedName = rawLeaveType['name']?.toString().trim();
      if (nestedName != null && nestedName.isNotEmpty) {
        return nestedName;
      }
    }

    // 3. Resolve the leave type ID used by the request against
    //    leave.getAvailableLeaveTypes, which returns id + name.
    final leaveTypeId = request['leaveTypeId']?.toString() ??
        (rawLeaveType is Map
            ? rawLeaveType['id']?.toString()
            : rawLeaveType?.toString());

    if (leaveTypeId != null && leaveTypeId.isNotEmpty) {
      for (final type in _availableTypes) {
        if (type is! Map) continue;

        if (type['id']?.toString() == leaveTypeId) {
          final name = type['name']?.toString().trim();
          if (name != null && name.isNotEmpty) {
            return name;
          }
        }
      }

      // 4. The balance response can also contain the friendly leave name.
      for (final balance in _balances) {
        if (balance is! Map) continue;

        final balanceId = balance['leaveTypeId']?.toString() ??
            balance['leaveType']?.toString() ??
            balance['id']?.toString();

        if (balanceId == leaveTypeId) {
          final name = balance['leaveTypeName']?.toString().trim() ??
              balance['name']?.toString().trim();
          if (name != null && name.isNotEmpty) {
            return name;
          }
        }
      }
    }

    // Never show a UUID/identifier to the user.
    return 'Leave Request';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int totalRequests = _requests.length;
    final int approvedCount = _requests.where((r) => r['status'] == 'approved').length;
    final int pendingCount = _requests.where((r) => r['status'] == 'pending').length;
    final bool hasNoLeaveTypes = _availableTypes.isEmpty;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Leave Management'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.add_circle_outline_rounded,
              color: hasNoLeaveTypes ? (isDark ? AppColors.darkIcon : AppColors.lightIcon) : AppColors.primaryCyan,
            ),
            onPressed: hasNoLeaveTypes ? null : _showApplyDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryCyan),
            )
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.error)))
              : RefreshIndicator(
                  onRefresh: _loadLeaveData,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.skyBlue.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.access_time_rounded,
                                      color: AppColors.skyBlue, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Quick Stats',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    title: 'Requests',
                                    count: '$totalRequests',
                                    bgColor: AppColors.skyBlue.withValues(alpha: 0.08),
                                    iconColor: AppColors.skyBlue,
                                    icon: Icons.description_rounded,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatCard(
                                    title: 'Approved',
                                    count: '$approvedCount',
                                    bgColor: AppColors.success.withValues(alpha: 0.08),
                                    iconColor: AppColors.success,
                                    icon: Icons.check_circle_rounded,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatCard(
                                    title: 'Pending',
                                    count: '$pendingCount',
                                    bgColor: AppColors.warning.withValues(alpha: 0.08),
                                    iconColor: AppColors.warning,
                                    icon: Icons.schedule_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (hasNoLeaveTypes) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: AppColors.warning),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'You currently have no leave types or balances assigned. Leave request actions are disabled.',
                                  style: TextStyle(
                                      color: isDark ? AppColors.warning : Colors.orange.shade800,
                                      fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      Text(
                        'Leave Balances',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 120,
                        child: _balances.isEmpty
                            ? Container(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                    'No leave balances available',
                                    style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _balances.length,
                                itemBuilder: (context, index) {
                                  final b = _balances[index];
                                  return Container(
                                    width: 110,
                                    margin: const EdgeInsets.only(right: 12),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          b['leaveTypeName'] ?? b['leaveType'],
                                          style: TextStyle(
                                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${b['remaining']}',
                                          style: const TextStyle(
                                              color: AppColors.primaryCyan,
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'of ${b['totalAllowed']} left',
                                          style: TextStyle(
                                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                              fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'My Leave Requests',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                          ),
                          TextButton.icon(
                            onPressed: hasNoLeaveTypes ? null : _showApplyDialog,
                            icon: Icon(Icons.add,
                                size: 16,
                                color: hasNoLeaveTypes
                                    ? (isDark ? AppColors.darkIcon : AppColors.lightIcon)
                                    : AppColors.primaryCyan),
                            label: Text('Apply Leave',
                                style: TextStyle(
                                    color: hasNoLeaveTypes
                                        ? (isDark ? AppColors.darkIcon : AppColors.lightIcon)
                                        : AppColors.primaryCyan)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _requests.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(30),
                              alignment: Alignment.center,
                              child: Text('No leave requests submitted',
                                  style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _requests.length,
                              itemBuilder: (context, index) {
                                final req = _requests[index];
                                final status =
                                    (req['status'] ?? 'pending').toString().toLowerCase();
                                final leaveTypeName = _getLeaveTypeName(req);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.darkSurface
                                        : AppColors.lightSurface,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              leaveTypeName,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? AppColors.darkTextPrimary
                                                    : AppColors.lightTextPrimary,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(status)
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              status.toUpperCase(),
                                              style: TextStyle(
                                                color: _getStatusColor(status),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 14,
                                            color: isDark
                                                ? AppColors.darkIcon
                                                : AppColors.lightIcon,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '${req['startDate']?.toString().split('T')[0]} to ${req['endDate']?.toString().split('T')[0]} (${req['totalDays']} days)',
                                              style: TextStyle(
                                                color: isDark
                                                    ? AppColors.darkTextSecondary
                                                    : AppColors.lightTextSecondary,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (req['reason'] != null &&
                                          req['reason']
                                              .toString()
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'Reason: ${req['reason']}',
                                          style: TextStyle(
                                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 12),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String count;
  final Color bgColor;
  final Color iconColor;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.count,
    required this.bgColor,
    required this.iconColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 10),
          Text(
            count,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ApplyLeaveForm extends StatefulWidget {
  final List<dynamic> availableTypes;
  final List<dynamic> balances;
  final VoidCallback onSuccess;

  const _ApplyLeaveForm({
    required this.availableTypes,
    required this.balances,
    required this.onSuccess,
  });

  @override
  State<_ApplyLeaveForm> createState() => _ApplyLeaveFormState();
}

class _ApplyLeaveFormState extends State<_ApplyLeaveForm> {
  final _leaveService = LeaveService();
  final _reasonController = TextEditingController();
  String? _selectedLeaveType;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _initDefaultLeaveType();
  }

  void _initDefaultLeaveType() {
    if (widget.availableTypes.isNotEmpty) {
      setState(() {
        _selectedLeaveType = widget.availableTypes[0]['id']?.toString();
      });
    }
  }

  int get _calculatedDays {
    if (_startDate == null || _endDate == null) return 0;
    if (_endDate!.isBefore(_startDate!)) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  Future<void> _submit() async {
    if (widget.availableTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot submit: No leave types assigned')),
      );
      return;
    }

    if (_selectedLeaveType == null || _startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _leaveService.createLeaveRequest(
        leaveType: _selectedLeaveType!,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate!),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate!),
        reason: _reasonController.text,
      );
      widget.onSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool hasNoTypes = widget.availableTypes.isEmpty;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New Leave Request',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          ),
          const SizedBox(height: 20),
          Text('Leave Type',
              style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _selectedLeaveType,
            dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
            items: widget.availableTypes.map<DropdownMenuItem<String>>((t) {
              return DropdownMenuItem<String>(
                value: t['id'].toString(),
                child: Text(t['name'] ?? t['id']),
              );
            }).toList(),
            onChanged: hasNoTypes
                ? null
                : (val) => setState(() => _selectedLeaveType = val),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start Date',
                        style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 13)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: hasNoTypes ? null : () => _selectDate(true),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _startDate != null
                              ? DateFormat('yyyy-MM-dd').format(_startDate!)
                              : 'Select date',
                          style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('End Date',
                        style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 13)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: hasNoTypes ? null : () => _selectDate(false),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _endDate != null
                              ? DateFormat('yyyy-MM-dd').format(_endDate!)
                              : 'Select date',
                          style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_calculatedDays > 0) ...[
            const SizedBox(height: 12),
            Text('Total Days: $_calculatedDays',
                style: const TextStyle(
                    color: AppColors.primaryCyan, fontWeight: FontWeight.bold)),
          ],
          const SizedBox(height: 16),
          Text('Reason (Optional)',
              style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            enabled: !hasNoTypes,
            style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
            decoration: InputDecoration(
              hintText: 'Reason for leave...',
              hintStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              filled: true,
              fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submitting || hasNoTypes ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryCyan,
                foregroundColor: AppColors.darkBackground,
                disabledBackgroundColor: isDark ? AppColors.darkSurfaceHighlight : AppColors.lightSurfaceHighlight,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      hasNoTypes ? 'No Leave Types Available' : 'Submit Request',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}