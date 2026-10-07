import 'package:hive_flutter/hive_flutter.dart';

class StorageService {
  static const String boxUser = 'user_box';
  static const String boxGoals = 'goals_box';
  static const String boxProgress = 'progress_box';
  static const String boxCohorts = 'cohorts_box';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(boxUser);
    await Hive.openBox<Map>(boxGoals);
    await Hive.openBox<Map>(boxProgress);
    await Hive.openBox<Map>(boxCohorts);
  }

  // Generic Helpers
  Box<Map> getBox(String boxName) {
    return Hive.box<Map>(boxName);
  }

  Future<void> clearAll() async {
    await Hive.box<Map>(boxUser).clear();
    await Hive.box<Map>(boxGoals).clear();
    await Hive.box<Map>(boxProgress).clear();
    await Hive.box<Map>(boxCohorts).clear();
  }
}
