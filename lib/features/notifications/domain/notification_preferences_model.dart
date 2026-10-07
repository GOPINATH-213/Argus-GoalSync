class NotificationPreferencesModel {
  final bool pushNotifications;
  final bool goalReminders;
  final bool streakAlerts;
  final bool competitorUpdates;
  final bool rankChanges;
  final bool achievements;

  NotificationPreferencesModel({
    this.pushNotifications = true,
    this.goalReminders = true,
    this.streakAlerts = true,
    this.competitorUpdates = true,
    this.rankChanges = true,
    this.achievements = true,
  });

  factory NotificationPreferencesModel.fromMap(Map<String, dynamic> map) {
    return NotificationPreferencesModel(
      pushNotifications: map['pushNotifications'] ?? true,
      goalReminders: map['goalReminders'] ?? true,
      streakAlerts: map['streakAlerts'] ?? true,
      competitorUpdates: map['competitorUpdates'] ?? true,
      rankChanges: map['rankChanges'] ?? true,
      achievements: map['achievements'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pushNotifications': pushNotifications,
      'goalReminders': goalReminders,
      'streakAlerts': streakAlerts,
      'competitorUpdates': competitorUpdates,
      'rankChanges': rankChanges,
      'achievements': achievements,
    };
  }

  NotificationPreferencesModel copyWith({
    bool? pushNotifications,
    bool? goalReminders,
    bool? streakAlerts,
    bool? competitorUpdates,
    bool? rankChanges,
    bool? achievements,
  }) {
    return NotificationPreferencesModel(
      pushNotifications: pushNotifications ?? this.pushNotifications,
      goalReminders: goalReminders ?? this.goalReminders,
      streakAlerts: streakAlerts ?? this.streakAlerts,
      competitorUpdates: competitorUpdates ?? this.competitorUpdates,
      rankChanges: rankChanges ?? this.rankChanges,
      achievements: achievements ?? this.achievements,
    );
  }
}
