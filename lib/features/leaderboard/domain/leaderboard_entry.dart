class LeaderboardEntry {
  final String userId;
  final String username;
  final String displayName;
  final String? photoUrl;
  final double currentValue;
  final double targetValue;
  final String unit;
  final double completionPercentage;
  final int currentStreak;
  final int totalCompletedDays;
  final double consistencyRate; // 0.0 to 1.0 (e.g. 0.85 for 85%)
  final double score; // Calculated sorting metric
  final String todayStatus; // 'Completed', 'Pending', 'Missed'

  LeaderboardEntry({
    required this.userId,
    required this.username,
    required this.displayName,
    this.photoUrl,
    required this.currentValue,
    required this.targetValue,
    required this.unit,
    required this.completionPercentage,
    required this.currentStreak,
    required this.totalCompletedDays,
    required this.consistencyRate,
    required this.score,
    required this.todayStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'currentValue': currentValue,
      'targetValue': targetValue,
      'unit': unit,
      'completionPercentage': completionPercentage,
      'currentStreak': currentStreak,
      'totalCompletedDays': totalCompletedDays,
      'consistencyRate': consistencyRate,
      'score': score,
      'todayStatus': todayStatus,
    };
  }

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return LeaderboardEntry(
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      displayName: map['displayName'] ?? '',
      photoUrl: map['photoUrl'],
      currentValue: (map['currentValue'] as num?)?.toDouble() ?? 0.0,
      targetValue: (map['targetValue'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] ?? '',
      completionPercentage: (map['completionPercentage'] as num?)?.toDouble() ?? 0.0,
      currentStreak: map['currentStreak'] ?? 0,
      totalCompletedDays: map['totalCompletedDays'] ?? 0,
      consistencyRate: (map['consistencyRate'] as num?)?.toDouble() ?? 0.0,
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
      todayStatus: map['todayStatus'] ?? 'Pending',
    );
  }
}
