class GoalProgress {
  final String id;
  final String goalId;
  final String userId;
  final DateTime date; // Year, Month, Day only
  final double value;
  final bool isCompleted;
  final DateTime updatedAt;

  GoalProgress({
    required this.id,
    required this.goalId,
    required this.userId,
    required this.date,
    required this.value,
    required this.isCompleted,
    required this.updatedAt,
  });

  GoalProgress copyWith({
    String? id,
    String? goalId,
    String? userId,
    DateTime? date,
    double? value,
    bool? isCompleted,
    DateTime? updatedAt,
  }) {
    return GoalProgress(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      value: value ?? this.value,
      isCompleted: isCompleted ?? this.isCompleted,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goalId': goalId,
      'userId': userId,
      'date': DateTime(date.year, date.month, date.day).toIso8601String(),
      'value': value,
      'isCompleted': isCompleted,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory GoalProgress.fromMap(Map<String, dynamic> map) {
    final parsedDate = map['date'] != null ? DateTime.parse(map['date']) : DateTime.now();
    return GoalProgress(
      id: map['id'] ?? '',
      goalId: map['goalId'] ?? '',
      userId: map['userId'] ?? '',
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      value: (map['value'] as num?)?.toDouble() ?? 0.0,
      isCompleted: map['isCompleted'] ?? false,
      updatedAt: map['updatedAt'] != null 
          ? DateTime.parse(map['updatedAt']) 
          : DateTime.now(),
    );
  }
}
