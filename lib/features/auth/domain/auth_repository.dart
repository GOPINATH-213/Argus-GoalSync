import 'user_profile.dart';

abstract class AuthRepository {
  Stream<UserProfile?> get authStateChanges;
  
  Future<UserProfile?> getCurrentUser();
  
  Future<UserProfile> loginWithEmail(String email, String password);
  
  Future<UserProfile> signUpWithEmail({
    required String email,
    required String password,
    required String username,
    required String displayName,
  });
  
  Future<void> logout();
  
  Future<UserProfile> updateProfile(UserProfile profile);
  
  Future<bool> isUsernameAvailable(String username);

  Future<void> deleteAccount(String uid);
}
