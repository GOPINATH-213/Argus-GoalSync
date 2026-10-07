class UserProfile {
  final String uid;
  final String email;
  final String username;
  final String displayName;
  final String? photoUrl;
  final int xp;
  final int level;
  final List<String> badges;
  final DateTime createdAt;

  UserProfile({
    required this.uid,
    required this.email,
    required this.username,
    required this.displayName,
    this.photoUrl,
    this.xp = 0,
    this.level = 1,
    this.badges = const [],
    required this.createdAt,
  });

  UserProfile copyWith({
    String? uid,
    String? email,
    String? username,
    String? displayName,
    String? photoUrl,
    int? xp,
    int? level,
    List<String>? badges,
    DateTime? createdAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      badges: badges ?? this.badges,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'xp': xp,
      'level': level,
      'badges': badges,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      displayName: map['displayName'] ?? '',
      photoUrl: map['photoUrl'],
      xp: map['xp'] ?? 0,
      level: map['level'] ?? 1,
      badges: List<String>.from(map['badges'] ?? const []),
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt']) 
          : DateTime.now(),
    );
  }
}
