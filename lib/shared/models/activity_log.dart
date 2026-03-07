class ActivityLog {
  final String id;
  final String action;
  final String description;
  final DateTime timestamp;
  final String? relatedEntityId;
  final String? relatedEntityType;

  ActivityLog({
    required this.id,
    required this.action,
    required this.description,
    required this.timestamp,
    this.relatedEntityId,
    this.relatedEntityType,
  });
}
