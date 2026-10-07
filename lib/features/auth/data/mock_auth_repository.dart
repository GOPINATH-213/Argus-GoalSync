import 'dart:async';
import '../domain/auth_repository.dart';
import '../domain/user_profile.dart';
import '../../../core/services/storage_service.dart';

class MockAuthRepository implements AuthRepository {
  final StorageService _storageService;
  final _authStateController = StreamController<UserProfile?>.broadcast();
  UserProfile? _currentUser;

  MockAuthRepository(this._storageService) {
    _loadUser();
  }

  void _loadUser() {
    final box = _storageService.getBox(StorageService.boxUser);
    final userMap = box.get('current_user');
    if (userMap != null) {
      _currentUser = UserProfile.fromMap(Map<String, dynamic>.from(userMap));
      _authStateController.add(_currentUser);
    } else {
      _authStateController.add(null);
    }
  }

  @override
  Stream<UserProfile?> get authStateChanges => _authStateController.stream;

  @override
  Future<UserProfile?> getCurrentUser() async {
    return _currentUser;
  }

  @override
  Future<UserProfile> loginWithEmail(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800)); // Simulate network latency

    final box = _storageService.getBox(StorageService.boxUser);
    final allUsers = box.get('all_mock_users') ?? {};
    
    if (allUsers.containsKey(email)) {
      final userMap = Map<String, dynamic>.from(allUsers[email]);
      if (userMap['password'] == password) {
        final profile = UserProfile.fromMap(userMap);
        _currentUser = profile;
        await box.put('current_user', profile.toMap());
        _authStateController.add(profile);
        return profile;
      } else {
        throw Exception('Incorrect password.');
      }
    } else {
      // Create a default demo account if it's the default credentials
      if (email == 'demo@goalsync.com' && password == 'password') {
        return signUpWithEmail(
          email: email,
          password: password,
          username: 'goalsync_demo',
          displayName: 'GoalSync Demo User',
        );
      }
      throw Exception('User not found. Register an account first.');
    }
  }

  @override
  Future<UserProfile> signUpWithEmail({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1000)); // Simulate latency

    final box = _storageService.getBox(StorageService.boxUser);
    final allUsers = Map<String, dynamic>.from(box.get('all_mock_users') ?? {});

    if (allUsers.containsKey(email)) {
      throw Exception('Email already in use.');
    }

    // Check username uniqueness
    for (var u in allUsers.values) {
      if (u['username'] == username) {
        throw Exception('Username already taken.');
      }
    }

    final profile = UserProfile(
      uid: 'mock_uid_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      username: username,
      displayName: displayName,
      xp: 0,
      level: 1,
      badges: [],
      createdAt: DateTime.now(),
    );

    final userMap = profile.toMap();
    userMap['password'] = password; // Store password locally for mock validation

    allUsers[email] = userMap;
    await box.put('all_mock_users', allUsers);

    _currentUser = profile;
    await box.put('current_user', profile.toMap());
    _authStateController.add(profile);
    
    return profile;
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
    final box = _storageService.getBox(StorageService.boxUser);
    await box.delete('current_user');
    _authStateController.add(null);
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    final box = _storageService.getBox(StorageService.boxUser);
    _currentUser = profile;
    await box.put('current_user', profile.toMap());
    
    // Also update in all_mock_users map
    final allUsers = Map<String, dynamic>.from(box.get('all_mock_users') ?? {});
    if (allUsers.containsKey(profile.email)) {
      final userMap = allUsers[profile.email];
      final newMap = profile.toMap();
      newMap['password'] = userMap['password']; // Preserve local password
      allUsers[profile.email] = newMap;
      await box.put('all_mock_users', allUsers);
    }
    
    _authStateController.add(profile);
    return profile;
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    final box = _storageService.getBox(StorageService.boxUser);
    final allUsers = Map<String, dynamic>.from(box.get('all_mock_users') ?? {});
    for (var u in allUsers.values) {
      if (u['username'].toString().toLowerCase() == username.toLowerCase()) {
        return false;
      }
    }
    return true;
  }

  @override
  Future<void> deleteAccount(String uid) async {
    final box = _storageService.getBox(StorageService.boxUser);
    final allUsers = Map<String, dynamic>.from(box.get('all_mock_users') ?? {});
    String? emailToDelete;
    
    allUsers.forEach((email, userMap) {
      if (userMap['uid'] == uid) {
        emailToDelete = email;
      }
    });
    
    if (emailToDelete != null) {
      allUsers.remove(emailToDelete);
      await box.put('all_mock_users', allUsers);
    }
    
    _currentUser = null;
    await box.delete('current_user');
    _authStateController.add(null);
  }
}
