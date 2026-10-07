import 'package:shared_preferences/shared_preferences.dart';

class ConfigService {
  static const String _keyUseFirebase = 'use_firebase';
  final SharedPreferences _prefs;

  ConfigService(this._prefs);

  bool get useFirebase {
    return _prefs.getBool(_keyUseFirebase) ?? true; // Default to Live Firebase Mode
  }

  Future<void> setUseFirebase(bool value) async {
    await _prefs.setBool(_keyUseFirebase, value);
  }
}
