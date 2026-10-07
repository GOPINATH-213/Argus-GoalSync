class Goal {
  final String id;
  final String userId;
  final String title;
  final String category;
  final double targetValue;
  final String unit;
  final String frequency; // 'Daily', 'Weekly', 'Monthly'
  final DateTime startDate;
  final DateTime? endDate;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastCompletedDate;
  final DateTime createdAt;

  final bool isCompletionPromptShown;
  final String? reminderTime; // format: "HH:mm"

  Goal({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.targetValue,
    required this.unit,
    required this.frequency, // 'Daily', 'Weekly', 'Monthly'
    required this.startDate,
    this.endDate,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastCompletedDate,
    required this.createdAt,
    this.isCompletionPromptShown = false,
    this.reminderTime,
  });

  Goal copyWith({
    String? id,
    String? userId,
    String? title,
    String? category,
    double? targetValue,
    String? unit,
    String? frequency,
    DateTime? startDate,
    DateTime? endDate,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastCompletedDate,
    DateTime? createdAt,
    bool? isCompletionPromptShown,
    String? reminderTime,
  }) {
    return Goal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      category: category ?? this.category,
      targetValue: targetValue ?? this.targetValue,
      unit: unit ?? this.unit,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      createdAt: createdAt ?? this.createdAt,
      isCompletionPromptShown: isCompletionPromptShown ?? this.isCompletionPromptShown,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'category': category,
      'targetValue': targetValue,
      'unit': unit,
      'frequency': frequency,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastCompletedDate': lastCompletedDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'isCompletionPromptShown': isCompletionPromptShown,
      'reminderTime': reminderTime,
    };
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      category: map['category'] ?? '',
      targetValue: (map['targetValue'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] ?? '',
      frequency: map['frequency'] ?? 'Daily',
      startDate: map['startDate'] != null 
          ? DateTime.parse(map['startDate']) 
          : DateTime.now(),
      endDate: map['endDate'] != null 
          ? DateTime.parse(map['endDate']) 
          : null,
      currentStreak: map['currentStreak'] ?? 0,
      longestStreak: map['longestStreak'] ?? 0,
      lastCompletedDate: map['lastCompletedDate'] != null 
          ? DateTime.parse(map['lastCompletedDate']) 
          : null,
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt']) 
          : DateTime.now(),
      isCompletionPromptShown: map['isCompletionPromptShown'] ?? false,
      reminderTime: map['reminderTime'],
    );
  }
}
