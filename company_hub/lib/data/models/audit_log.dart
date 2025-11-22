// lib/data/models/audit_log.dart
class AuditLog {
  final int id;
  final int userId;
  final String action;
  final String? resource;
  final String? resourceId;
  final String? ipAddress;
  final String? userAgent;
  final DateTime timestamp;
  final String? details;

  AuditLog({
    required this.id,
    required this.userId,
    required this.action,
    this.resource,
    this.resourceId,
    this.ipAddress,
    this.userAgent,
    required this.timestamp,
    this.details,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'],
      userId: json['user_id'],
      action: json['action'],
      resource: json['resource'],
      resourceId: json['resource_id'],
      ipAddress: json['ip_address'],
      userAgent: json['user_agent'],
      timestamp: DateTime.parse(json['timestamp']),
      details: json['details'],
    );
  }
}
