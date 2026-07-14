class UserFeedbackEntry {
  final String taskId;
  final String taskTitle;
  final String clientId;
  final String clientName;
  final double rating; // 1–5
  final String? comment;
  final String? domain;
  final DateTime? createdAt;

  UserFeedbackEntry({
    required this.taskId,
    required this.taskTitle,
    required this.clientId,
    required this.clientName,
    required this.rating,
    this.comment,
    this.domain,
    this.createdAt,
  });

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  factory UserFeedbackEntry.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['createdAt'];
    return UserFeedbackEntry(
      taskId: (json['taskId'] ?? '').toString(),
      taskTitle: json['taskTitle']?.toString() ?? '',
      clientId: (json['clientId'] ?? '').toString(),
      clientName: json['clientName']?.toString() ?? '',
      rating: _toDouble(json['rating']),
      comment: json['comment']?.toString(),
      domain: json['domain']?.toString(),
      createdAt: createdRaw is String ? DateTime.tryParse(createdRaw) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'taskTitle': taskTitle,
      'clientId': clientId,
      'clientName': clientName,
      'rating': rating,
      'comment': comment,
      'domain': domain,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

class UserFeedbackDomainScore {
  final String domain;
  final double totalScore;
  final int count;

  double get average => count == 0 ? 0 : totalScore / count;

  UserFeedbackDomainScore({
    required this.domain,
    required this.totalScore,
    required this.count,
  });

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  factory UserFeedbackDomainScore.fromJson(Map<String, dynamic> json) {
    return UserFeedbackDomainScore(
      domain: json['domain']?.toString() ?? '',
      totalScore: _toDouble(json['totalScore']),
      count: _toInt(json['count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'domain': domain,
      'totalScore': totalScore,
      'count': count,
    };
  }
}

class User {
  String id;
  String name;
  String email;
  final String mobile;
  String role;

  String? company;
  String? location; 
  bool isApproved;

  // profile images
  String? avatarUrl;
  String? bannerUrl;

  // student profile
  // String? bio;
  String? portfolioUrl;
  List<String> skills;

  // ============================================================
  // MODIFICATION: IDENTITY PROOF (Firebase Storage URL)
  // ============================================================
  String idCardUrl;
  
  // reputation & history (Used for Admin Sorting)
  int tasksCompleted;
  double totalScore;
  int totalScoreCount;

  // bank details
  String bankAccountHolderName;
  String bankAccountNumber;
  String ifscCode;

  // domain aggregates
  List<UserFeedbackDomainScore> feedbackScores;

  // detailed feedback list per project/task
  List<UserFeedbackEntry> feedbackEntries;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile, 
    required this.role,
    this.company,
    this.location,
    required this.isApproved,
    this.avatarUrl,
    this.bannerUrl,
    // this.bio,
    this.portfolioUrl,
    this.skills = const [],
    this.idCardUrl = '', // Default to empty string
    this.tasksCompleted = 0,
    this.totalScore = 0,
    this.totalScoreCount = 0,
    this.bankAccountHolderName = '',
    this.bankAccountNumber = '',
    this.ifscCode = '',
    this.feedbackScores = const [],
    this.feedbackEntries = const [],
  });

  double get averageRating =>
      totalScoreCount == 0 ? 0 : totalScore / totalScoreCount;

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static List<String> _toStringList(dynamic v) {
    if (v is List) {
      return v.map((e) => e.toString()).toList();
    }
    return const [];
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      company: json['company']?.toString(),
      location: json['location']?.toString(),
      isApproved: json['isApproved'] is bool
          ? json['isApproved'] as bool
          : true,
      avatarUrl: json['avatarUrl']?.toString(),
      bannerUrl: json['bannerUrl']?.toString(),
      // bio: json['bio']?.toString(),
      portfolioUrl: json['portfolioUrl']?.toString(),
      skills: _toStringList(json['skills']),
      idCardUrl: json['idCardUrl']?.toString() ?? '', // Map idCardUrl
      tasksCompleted: _toInt(json['tasksCompleted']),
      totalScore: _toDouble(json['totalScore']),
      totalScoreCount: _toInt(json['totalScoreCount']),
      bankAccountHolderName: (json['bankAccountHolderName'] ?? '').toString(),
      bankAccountNumber: (json['bankAccountNumber'] ?? '').toString(),
      ifscCode: (json['ifscCode'] ?? '').toString(),
      feedbackScores: (json['feedbackScores'] as List<dynamic>?)
              ?.map((e) =>
                  UserFeedbackDomainScore.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      feedbackEntries: (json['feedbackEntries'] as List<dynamic>?)
              ?.map(
                  (e) => UserFeedbackEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'role': role,
      'company': company,
      'location': location,
      'isApproved': isApproved,
      'avatarUrl': avatarUrl,
      'bannerUrl': bannerUrl,
      // 'bio': bio,
      'portfolioUrl': portfolioUrl,
      'skills': skills,
      'idCardUrl': idCardUrl, // Export idCardUrl
      'tasksCompleted': tasksCompleted,
      'totalScore': totalScore,
      'totalScoreCount': totalScoreCount,
      'bankAccountHolderName': bankAccountHolderName,
      'bankAccountNumber': bankAccountNumber,
      'ifscCode': ifscCode,
      'feedbackScores': feedbackScores.map((e) => e.toJson()).toList(),
      'feedbackEntries': feedbackEntries.map((e) => e.toJson()).toList(),
    };
  }
}