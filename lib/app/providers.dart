import 'dart:convert';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../data/drift_meal_repository.dart';
import '../data/backup_service.dart';
import '../data/file_photo_store.dart';
import '../data/image_photo_importer.dart';
import '../data/geo/place_catalog.dart';
import '../domain/meal_repository.dart';
import '../domain/models.dart';
import '../domain/photo_importer.dart';
import '../domain/photo_store.dart';

/// 单例数据库。UI 永不直接依赖 drift 的生成类型（见 ADR-0002）。
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(driftDatabase(name: 'mealmap'));
  ref.onDispose(db.close);
  return db;
});

final photoStoreProvider = Provider<PhotoFileStore>((ref) => FilePhotoStore());

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    ref.watch(mealRepositoryProvider),
    ref.watch(photoStoreProvider),
  );
});

final photoImporterProvider = Provider<PhotoImporter>((ref) {
  return ImagePhotoImporter(ref.watch(photoStoreProvider));
});

final mealRepositoryProvider = Provider<MealRepository>((ref) {
  return DriftMealRepository(
    ref.watch(databaseProvider),
    ref.watch(photoStoreProvider),
  );
});

/// 行政区点位目录（只含点，不含边界，见 ADR-0003）。
final placeCatalogProvider = FutureProvider<PlaceCatalog>((ref) async {
  final raw = await rootBundle.loadString('assets/data/places.json');
  return PlaceCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
});

/// 可选菜系（不含归档项）。
final cuisinesProvider = FutureProvider<List<Cuisine>>((ref) {
  return ref.watch(mealRepositoryProvider).listCuisines();
});

/// 全部菜系，含已归档；设置页用。
final allCuisinesProvider = FutureProvider<List<Cuisine>>((ref) {
  return ref.watch(mealRepositoryProvider).listCuisines(includeArchived: true);
});

final tagsProvider = FutureProvider<List<Tag>>((ref) {
  return ref.watch(mealRepositoryProvider).listTags();
});
