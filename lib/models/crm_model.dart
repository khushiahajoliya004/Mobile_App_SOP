class CrmLead {
  final String id;
  final String customerName;
  final String status;
  final String? phone;
  final String? source;
  final String? assignedToUserId;
  final String? assignedToUserName;
  final DateTime? bookingDate;
  final DateTime? deliveryDate;
  final DateTime? nextFollowUpAt;

  CrmLead({
    required this.id,
    required this.customerName,
    required this.status,
    this.phone,
    this.source,
    this.assignedToUserId,
    this.assignedToUserName,
    this.bookingDate,
    this.deliveryDate,
    this.nextFollowUpAt,
  });

  factory CrmLead.fromJson(Map<String, dynamic> json) {
    final assignedTo = json['assignedTo'];
    String? assignedName;
    if (assignedTo is Map) {
      assignedName =
          '${assignedTo['firstName'] ?? ''} ${assignedTo['lastName'] ?? ''}'
              .trim();
      if (assignedName.isEmpty) assignedName = null;
    }
    return CrmLead(
      id: json['id'] ?? '',
      customerName: json['customerName'] ?? '',
      status: json['status'] ?? 'OPEN',
      phone: json['phone'],
      source: json['source'],
      assignedToUserId: json['assignedToUserId'],
      assignedToUserName: assignedName,
      bookingDate: DateTime.tryParse(json['bookingDate'] ?? ''),
      deliveryDate: DateTime.tryParse(json['deliveryDate'] ?? ''),
      nextFollowUpAt: DateTime.tryParse(json['nextFollowUpAt'] ?? ''),
    );
  }

  bool get isAssigned =>
      assignedToUserId != null && assignedToUserId!.isNotEmpty;
}

class CrmFollowUp {
  final String id;
  final String status;
  final String type;
  final DateTime scheduledAt;
  final String leadName;

  CrmFollowUp({
    required this.id,
    required this.status,
    required this.type,
    required this.scheduledAt,
    required this.leadName,
  });

  factory CrmFollowUp.fromJson(Map<String, dynamic> json) => CrmFollowUp(
    id: json['id'] ?? '',
    status: json['status'] ?? 'PENDING',
    type: json['type'] ?? 'CALL',
    scheduledAt: DateTime.tryParse(json['scheduledAt'] ?? '') ?? DateTime.now(),
    leadName: json['lead']?['customerName'] ?? 'Lead',
  );
}

class CrmVisit {
  final String id;
  final String status;
  final DateTime scheduledAt;
  final String leadName;

  CrmVisit({
    required this.id,
    required this.status,
    required this.scheduledAt,
    required this.leadName,
  });

  factory CrmVisit.fromJson(Map<String, dynamic> json) => CrmVisit(
    id: json['id'] ?? '',
    status: json['status'] ?? 'PLANNED',
    scheduledAt: DateTime.tryParse(json['scheduledAt'] ?? '') ?? DateTime.now(),
    leadName: json['lead']?['customerName'] ?? 'Lead',
  );
}
