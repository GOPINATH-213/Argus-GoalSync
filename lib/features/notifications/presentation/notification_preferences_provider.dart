import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/notification_preferences_model.dart';

class NotificationPreferencesController extends StateNotifier<AsyncValue<NotificationPreferencesModel>> {
  final Ref _ref;

  NotificationPreferencesController(this._ref) : super(const AsyncValue.loading()) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final user = _ref.read(currentUserProvider).value;
    if (user == null) {
      state = AsyncValue.data(NotificationPreferencesModel());
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preferences')
          .doc('notifications')
          .get();

      if (doc.exists && doc.data() != null) {
        state = AsyncValue.data(NotificationPreferencesModel.fromMap(doc.data()!));
      } else {
        state = AsyncValue.data(NotificationPreferencesModel());
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updatePreferences(NotificationPreferencesModel prefs) async {
    final user = _ref.read(currentUserProvider).value;
    if (user == null) return;

    // Optimistic update
    state = AsyncValue.data(prefs);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preferences')
          .doc('notifications')
          .set(prefs.toMap(), SetOptions(merge: true));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final notificationPreferencesProvider = StateNotifierProvider<NotificationPreferencesController, AsyncValue<NotificationPreferencesModel>>((ref) {
  return NotificationPreferencesController(ref);
});
