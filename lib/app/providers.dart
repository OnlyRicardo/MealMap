import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../data/drift_meal_repository.dart';
import '../data/file_photo_store.dart';
import '../domain/meal_repository.dart';
import '../domain/photo_store.dart';

/// 单例数据库。UI 永不直接依赖 drift 的生成类型（见 ADR-0002）。
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(driftDatabase(name: 'mealmap'));
  ref.onDispose(db.close);
  return db;
});

final photoStoreProvider = Provider<PhotoFileStore>((ref) => FilePhotoStore());

final mealRepositoryProvider = Provider<MealRepository>((ref) {
  return DriftMealRepository(
    ref.watch(databaseProvider),
    photoStore: ref.watch(photoStoreProvider),
  );
});
