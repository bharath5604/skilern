// lib/models/task.dart

class Task {
  final String id;
  final String title;
  final String description;

  final String? clientId; // Optional for guest tasks
  final String? clientName;

  final double? budget; // Requirement: Estimated amount is optional
  final String status;

  final String? location;
  final String? domain;
  final String? company;
  final List<String> requiredSkills;
  final String? deadline;

  final List<String> attachments;
  final List<String> attachmentNames;

  final String? requestedStudentId;
  final String? requestedStudentName;

  final String? assignedStudentId;
  final String? assignedStudentName;

  final bool clientTermsAccepted;
  final bool studentTermsAccepted;

  // ============================================================
  // MODIFICATION: MULTI-FILE SUBMISSION SUPPORT
  // Replaced single submissionFile string with a list of file objects
  // Each map contains {'url': '...', 'name': '...'}
  // ============================================================
  final List<Map<String, String>> submissionFiles; 
  final String? submissionNotes;
  final String? submittedAt;

  final bool submissionApproved;
  final bool clientApproved;

  final int rating;
  final int score;
  final String feedback;

  final bool isGuestTask;
  final String? guestName;
  final String? guestMobile;
  final String? guestEmail;

  // --- GATING LOGIC PROPERTIES ---
  final bool clientCanViewSubmission;
  final bool clientCanDownload;

  // --- PAYMENT CHAIN TRACKING ---
  final bool adminReceivedPayment;
  final bool adminPaidStudent;

  // --- HYBRID PAYMENT SWITCH ---
  final bool budgetFinalized;

  // Stores the reason/notes provided when a client requests modification.
  final String? modificationNotes;

  const Task({
    required this.id,
    required this.title,
    required this.description,
    this.clientId,
    this.clientName,
    this.budget,
    required this.status,
    this.location,
    this.domain,
    this.company,
    this.requiredSkills = const [],
    this.deadline,
    this.attachments = const [],
    this.attachmentNames = const [],
    this.requestedStudentId,
    this.requestedStudentName,
    this.assignedStudentId,
    this.assignedStudentName,
    this.clientTermsAccepted = false,
    this.studentTermsAccepted = false,
    this.submissionFiles = const [], // Default to empty list
    this.submissionNotes,
    this.submittedAt,
    this.submissionApproved = false,
    this.clientApproved = false,
    this.rating = 0,
    this.score = 0,
    this.feedback = '',
    this.isGuestTask = false,
    this.guestName,
    this.guestMobile,
    this.guestEmail,
    this.clientCanViewSubmission = true,
    this.clientCanDownload = false,
    this.adminReceivedPayment = false,
    this.adminPaidStudent = false,
    this.budgetFinalized = false,
    this.modificationNotes = '', 
  });

  static double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static bool _toBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == 'true' || v == '1';
    }
    if (value is num) return value != 0;
    return fallback;
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e?.toString() ?? '')
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    return const [];
  }

  // Helper to parse the new files array in submission
  static List<Map<String, String>> _toFileMapList(dynamic value) {
    if (value is List) {
      return value.map((item) {
        if (item is Map) {
          return {
            'url': item['url']?.toString() ?? '',
            'name': item['name']?.toString() ?? 'Untitled File',
          };
        }
        return <String, String>{};
      }).where((element) => element.isNotEmpty).toList();
    }
    return const [];
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    final client = json['client'] is Map ? json['client'] : null;
    final guestInfo = json['guestInfo'] is Map ? json['guestInfo'] : null;
    final requestedStudent =
        json['requestedStudent'] is Map ? json['requestedStudent'] : null;
    final student = (json['student'] ?? json['assignedTo']) is Map
        ? (json['student'] ?? json['assignedTo'])
        : null;
    final submission = json['submission'] is Map ? json['submission'] : null;

    return Task(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      clientId: client?['_id']?.toString(),
      clientName: client?['name']?.toString(),
      budget: _toDoubleOrNull(json['budget']),
      status: json['status']?.toString() ?? 'open',
      location: json['location']?.toString(),
      domain: json['domain']?.toString(),
      company: json['company']?.toString() ?? client?['company']?.toString(),
      requiredSkills: _toStringList(json['requiredSkills']),
      deadline: json['deadline']?.toString(),
      attachments: _toStringList(json['attachments']),
      attachmentNames: _toStringList(json['attachmentNames']),
      requestedStudentId: requestedStudent?['_id']?.toString(),
      requestedStudentName: requestedStudent?['name']?.toString(),
      assignedStudentId: student?['_id']?.toString(),
      assignedStudentName: student?['name']?.toString(),
      clientTermsAccepted: _toBool(json['clientAgreedToTerms']),
      studentTermsAccepted: _toBool(json['studentAgreedToTerms']),
      
      // UPDATED MAPPING: Handle multiple files
      submissionFiles: _toFileMapList(submission?['files']),
      
      submissionNotes: submission?['notes']?.toString(),
      submittedAt: submission?['submittedAt']?.toString(),
      submissionApproved: _toBool(submission?['approved']),
      clientApproved: _toBool(submission?['approved']),
      rating: int.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      score: int.tryParse(json['score']?.toString() ?? '0') ?? 0,
      feedback: json['feedback']?.toString() ?? '',
      isGuestTask: _toBool(json['isGuestTask']),
      guestName: guestInfo?['name']?.toString(),
      guestMobile: guestInfo?['mobile']?.toString(),
      guestEmail: guestInfo?['email']?.toString(),
      clientCanViewSubmission:
          _toBool(json['clientCanViewSubmission'], fallback: true),
      clientCanDownload: _toBool(json['clientCanDownload'], fallback: false),
      adminReceivedPayment: _toBool(json['adminReceivedPayment']),
      adminPaidStudent: _toBool(json['adminPaidStudent']),
      budgetFinalized: _toBool(json['budgetFinalized']),
      modificationNotes: json['modificationNotes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'description': description,
      'status': status,
      'isGuestTask': isGuestTask,
      'clientCanViewSubmission': clientCanViewSubmission,
      'clientCanDownload': clientCanDownload,
      'adminReceivedPayment': adminReceivedPayment,
      'adminPaidStudent': adminPaidStudent,
      'budgetFinalized': budgetFinalized,
      'budget': budget,
      'modificationNotes': modificationNotes,
      // Note: We don't usually send full submission objects back in toJson for task updates,
      // but if needed, you would export submissionFiles here.
    };
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? status,
    bool? clientCanViewSubmission,
    bool? clientCanDownload,
    bool? adminReceivedPayment,
    bool? adminPaidStudent,
    bool? budgetFinalized,
    double? budget,
    String? modificationNotes,
    List<Map<String, String>>? submissionFiles,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      clientId: clientId,
      clientName: clientName,
      budget: budget ?? this.budget,
      status: status ?? this.status,
      location: location,
      domain: domain,
      company: company,
      requiredSkills: requiredSkills,
      deadline: deadline,
      attachments: attachments,
      attachmentNames: attachmentNames,
      requestedStudentId: requestedStudentId,
      requestedStudentName: requestedStudentName,
      assignedStudentId: assignedStudentId,
      assignedStudentName: assignedStudentName,
      clientTermsAccepted: clientTermsAccepted,
      studentTermsAccepted: studentTermsAccepted,
      submissionFiles: submissionFiles ?? this.submissionFiles,
      submissionNotes: submissionNotes,
      submittedAt: submittedAt,
      submissionApproved: submissionApproved,
      clientApproved: clientApproved,
      rating: rating,
      score: score,
      feedback: feedback,
      isGuestTask: isGuestTask,
      guestName: guestName,
      guestMobile: guestMobile,
      guestEmail: guestEmail,
      clientCanViewSubmission:
          clientCanViewSubmission ?? this.clientCanViewSubmission,
      clientCanDownload: clientCanDownload ?? this.clientCanDownload,
      adminReceivedPayment: adminReceivedPayment ?? this.adminReceivedPayment,
      adminPaidStudent: adminPaidStudent ?? this.adminPaidStudent,
      budgetFinalized: budgetFinalized ?? this.budgetFinalized,
      modificationNotes: modificationNotes ?? this.modificationNotes,
    );
  }

  bool get isOpen => status == 'open';
  bool get isAssigned => status == 'assigned';
  bool get isUnderReview => status == 'under_review';
  bool get isCompleted => status == 'completed';
  
  // UPDATED: Now checks if the list contains files
  bool get hasSubmission => submissionFiles.isNotEmpty;
}