import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/bundle.dart';
import '../../domain/meal_repository.dart';
import '../../domain/models.dart';
import '../../domain/photo_store.dart';
import '../../domain/rules.dart';
import 'db/database.dart';

class DriftMealRepository implements MealRepository {
  DriftMealRepository(
    this._db,
    this._photoStore, {
    DateTime Function()? now,
    Uuid? uuid,
  }) : _now = now ?? (() => DateTime.now()),
       _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final PhotoFileStore _photoStore;
  final DateTime Function() _now;
  final Uuid _uuid;

  // ---------------------------------------------------------------- cuisines

  @override
  Future<List<Cuisine>> listCuisines({bool includeArchived = false}) async {
    final query = _db.select(_db.cuisines);
    if (!includeArchived) {
      query.where((row) => row.archivedAt.isNull());
    }
    query.orderBy([(row) => OrderingTerm.asc(row.sortOrder), (row) => OrderingTerm.asc(row.name)]);
    final rows = await query.get();
    return rows.map(_toCuisine).toList();
  }

  @override
  Future<int> seedCuisines(List<CuisineSeed> seeds) async {
    var inserted = 0;
    await _db.transaction(() async {
      final existing = (await _db.select(_db.cuisines).get()).map((c) => c.id).toSet();
      for (final seed in seeds) {
        if (existing.contains(seed.id)) continue;
        await _db.into(_db.cuisines).insert(CuisinesCompanion.insert(
              id: seed.id,
              name: seed.name,
              isBuiltin: const Value(true),
              sortOrder: Value(seed.sortOrder),
            ));
        inserted++;
      }
    });
    return inserted;
  }

  @override
  Future<Cuisine> addCuisine(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const CuisineNameConflictException('菜系名称不能为空');
    }
    final clash = await (_db.select(_db.cuisines)
          ..where((row) => row.name.lower().equals(trimmed.toLowerCase())))
        .getSingleOrNull();
    if (clash != null) {
      throw CuisineNameConflictException('菜系「$trimmed」已存在');
    }
    final maxOrder = await _maxCuisineOrder();
    // 自定义菜系始终排在内置菜系（sortOrder ≤ 1000）之后。
    final order = (maxOrder < 1000 ? 1000 : maxOrder) + 10;
    final row = Cuisine(
      id: _uuid.v4(),
      name: trimmed,
      isBuiltin: false,
      sortOrder: order,
    );
    await _db.into(_db.cuisines).insert(CuisinesCompanion.insert(
          id: row.id,
          name: row.name,
          isBuiltin: Value(row.isBuiltin),
          sortOrder: Value(row.sortOrder),
        ));
    return row;
  }

  @override
  Future<void> renameCuisine(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const CuisineNameConflictException('菜系名称不能为空');
    }
    final clash = await (_db.select(_db.cuisines)..where((row) =>
            row.name.lower().equals(trimmed.toLowerCase()) & row.id.equals(id).not()))
        .getSingleOrNull();
    if (clash != null) {
      throw CuisineNameConflictException('菜系「$trimmed」已存在');
    }
    await (_db.update(_db.cuisines)..where((row) => row.id.equals(id)))
        .write(CuisinesCompanion(name: Value(trimmed)));
  }

  @override
  Future<void> archiveCuisine(String id) async {
    await (_db.update(_db.cuisines)..where((row) => row.id.equals(id)))
        .write(CuisinesCompanion(archivedAt: Value(_now())));
  }

  @override
  Future<void> restoreCuisine(String id) async {
    await (_db.update(_db.cuisines)..where((row) => row.id.equals(id)))
        .write(const CuisinesCompanion(archivedAt: Value(null)));
  }

  Future<int> _maxCuisineOrder() async {
    final row = await (_db.selectOnly(_db.cuisines)
          ..addColumns([_db.cuisines.sortOrder.max()]))
        .getSingle();
    return row.read(_db.cuisines.sortOrder.max()) ?? 0;
  }

  // -------------------------------------------------------------------- tags

  @override
  Future<List<Tag>> listTags() async {
    final rows = await (_db.select(_db.tags)
          ..orderBy([(row) => OrderingTerm.asc(row.name)]))
        .get();
    return rows.map((row) => Tag(id: row.id, name: row.name)).toList();
  }

  @override
  Future<Tag> upsertTag(String name) async {
    final trimmed = _normalizeTag(name);
    final existing = await (_db.select(_db.tags)
          ..where((row) => row.normalizedName.equals(trimmed.toLowerCase())))
        .getSingleOrNull();
    if (existing != null) {
      return Tag(id: existing.id, name: existing.name);
    }
    final tag = Tag(id: _uuid.v4(), name: trimmed);
    await _db.into(_db.tags).insert(TagsCompanion.insert(
          id: tag.id,
          name: tag.name,
          normalizedName: tag.name.toLowerCase(),
          createdAt: _now(),
        ));
    return tag;
  }

  @override
  Future<void> renameTag(String id, String name) async {
    final trimmed = _normalizeTag(name);
    final clash = await (_db.select(_db.tags)
          ..where((row) =>
              row.normalizedName.equals(trimmed.toLowerCase()) &
              row.id.equals(id).not()))
        .getSingleOrNull();
    if (clash != null) {
      throw CuisineNameConflictException('标签「$trimmed」已存在');
    }
    await (_db.update(_db.tags)..where((row) => row.id.equals(id))).write(
      TagsCompanion(
        name: Value(trimmed),
        normalizedName: Value(trimmed.toLowerCase()),
      ),
    );
  }

  @override
  Future<void> mergeTags(String fromId, String intoId) async {
    if (fromId == intoId) return;
    await _db.transaction(() async {
      final links = await (_db.select(_db.mealTags)
            ..where((row) => row.tagId.equals(fromId)))
          .get();
      for (final link in links) {
        await _db.into(_db.mealTags).insert(
              MealTagsCompanion.insert(mealId: link.mealId, tagId: intoId),
              mode: InsertMode.insertOrIgnore,
            );
      }
      await (_db.delete(_db.mealTags)..where((row) => row.tagId.equals(fromId)))
          .go();
      await (_db.delete(_db.tags)..where((row) => row.id.equals(fromId))).go();
    });
  }

  @override
  Future<void> deleteTag(String id) async {
    await (_db.delete(_db.tags)..where((row) => row.id.equals(id))).go();
  }

  String _normalizeTag(String raw) {
    final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.length < kMinTagLength || trimmed.length > kMaxTagLength) {
      throw InvalidTagNameException(
        '标签需 $kMinTagLength–$kMaxTagLength 个字符：$trimmed',
      );
    }
    return trimmed;
  }

  // ------------------------------------------------------------------- meals

  @override
  Future<List<Meal>> mealsOn(DateTime date) async {
    final rows = await (_db.select(_db.meals)
          ..where((row) => row.eatenOn.equals(dateKey(date)))
          ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
        .get();
    return Future.wait(rows.map(_hydrate));
  }

  @override
  Future<List<Meal>> mealsBetween(DateTime from, DateTime to) async {
    final rows = await (_db.select(_db.meals)
          ..where((row) =>
              row.eatenOn.isBiggerOrEqualValue(dateKey(from)) &
              row.eatenOn.isSmallerOrEqualValue(dateKey(to)))
          ..orderBy([
            (row) => OrderingTerm.asc(row.eatenOn),
            (row) => OrderingTerm.asc(row.createdAt),
          ]))
        .get();
    return Future.wait(rows.map(_hydrate));
  }

  @override
  Future<Meal?> mealById(String id) async {
    final row = await (_db.select(_db.meals)..where((row) => row.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return _hydrate(row);
  }

  @override
  Future<Meal> saveMeal(MealDraft draft) async {
    final photos = draft.photos;
    if (photos.length > kMaxPhotosPerMeal) {
      throw PhotoLimitException('一餐最多 $kMaxPhotosPerMeal 张照片');
    }
    if (draft.tagNames.length > kMaxTagsPerMeal) {
      throw TagLimitException('一餐最多 $kMaxTagsPerMeal 个标签');
    }
    if (draft.dishes.length > kMaxDishesPerMeal) {
      throw MealMapException('一餐最多 $kMaxDishesPerMeal 道菜');
    }
    if (draft.cityCode.trim().isEmpty) {
      throw const MealMapException('请选择城市');
    }
    final cuisine = await (_db.select(_db.cuisines)
          ..where((row) => row.id.equals(draft.cuisineId)))
        .getSingleOrNull();
    if (cuisine == null) {
      throw UnknownCuisineException('菜系不存在：${draft.cuisineId}');
    }

    final tagNames = <String>[];
    for (final raw in draft.tagNames) {
      final normalized = _normalizeTag(raw);
      if (!tagNames.any((t) => t.toLowerCase() == normalized.toLowerCase())) {
        tagNames.add(normalized);
      }
    }
    final tagIds = <String>[];
    for (final name in tagNames) {
      tagIds.add((await upsertTag(name)).id);
    }

    final id = draft.id ?? _uuid.v4();
    final existingRow = draft.id == null
        ? null
        : await (_db.select(_db.meals)..where((row) => row.id.equals(id)))
            .getSingleOrNull();
    final existingPhotos = existingRow == null
        ? const <PhotoRow>[]
        : await (_db.select(_db.photos)
              ..where((row) => row.mealId.equals(id)))
            .get();

    await _db.transaction(() async {
      await _db.into(_db.meals).insertOnConflictUpdate(MealsCompanion.insert(
            id: id,
            eatenOn: dateKey(draft.eatenOn),
            slot: Value(draft.slot?.name),
            cityCode: draft.cityCode.trim(),
            cuisineId: draft.cuisineId,
            note: Value(draft.note?.trim()),
            createdAt: existingRow?.createdAt ?? _now(),
            updatedAt: _now(),
          ));

      await (_db.delete(_db.dishes)..where((row) => row.mealId.equals(id))).go();
      for (var i = 0; i < draft.dishes.length; i++) {
        final name = draft.dishes[i].trim();
        if (name.isEmpty) continue;
        await _db.into(_db.dishes).insert(DishesCompanion.insert(
              id: _uuid.v4(),
              mealId: id,
              name: name,
              position: i,
            ));
      }

      await (_db.delete(_db.photos)..where((row) => row.mealId.equals(id))).go();
      for (var i = 0; i < photos.length; i++) {
        final photo = photos[i];
        await _db.into(_db.photos).insert(PhotosCompanion.insert(
              id: photo.id ?? _uuid.v4(),
              mealId: id,
              fileName: photo.fileName,
              thumbName: photo.thumbName,
              width: photo.width,
              height: photo.height,
              position: i,
            ));
      }

      await (_db.delete(_db.mealTags)..where((row) => row.mealId.equals(id)))
          .go();
      for (final tagId in tagIds) {
        await _db.into(_db.mealTags).insert(MealTagsCompanion.insert(
              mealId: id,
              tagId: tagId,
            ));
      }
    });

    // 事务成功后才删文件，避免回滚后照片已经没了。
    final keptNames = photos.map((p) => p.fileName).toSet();
    for (final old in existingPhotos) {
      if (!keptNames.contains(old.fileName)) {
        await _photoStore.delete(old.fileName);
        await _photoStore.delete(old.thumbName);
      }
    }

    return (await mealById(id))!;
  }

  @override
  Future<void> deleteMeal(String id) async {
    final photos = await (_db.select(_db.photos)
          ..where((row) => row.mealId.equals(id)))
        .get();
    await (_db.delete(_db.meals)..where((row) => row.id.equals(id))).go();
    for (final photo in photos) {
      await _photoStore.delete(photo.fileName);
      await _photoStore.delete(photo.thumbName);
    }
  }

  // ------------------------------------------------------------- aggregation

  @override
  Future<List<CityCount>> cityCounts({int? year}) async {
    final count = _db.meals.id.count();
    final query = _db.selectOnly(_db.meals)
      ..addColumns([_db.meals.cityCode, count])
      ..groupBy([_db.meals.cityCode]);
    if (year != null) {
      query.where(_db.meals.eatenOn.like('$year-%'));
    }
    final rows = await query.get();
    return rows
        .map((row) => CityCount(
              cityCode: row.read(_db.meals.cityCode)!,
              count: row.read(count)!,
            ))
        .toList();
  }

  @override
  Future<List<CuisineCount>> cuisineCounts({int? year}) async {
    final count = _db.meals.id.count();
    final query = _db.selectOnly(_db.meals)
      ..addColumns([_db.meals.cuisineId, count])
      ..groupBy([_db.meals.cuisineId]);
    if (year != null) {
      query.where(_db.meals.eatenOn.like('$year-%'));
    }
    final rows = await query.get();
    return rows
        .map((row) => CuisineCount(
              cuisineId: row.read(_db.meals.cuisineId)!,
              count: row.read(count)!,
            ))
        .toList();
  }

  @override
  Future<List<int>> yearsWithMeals() async {
    final rows = await _db
        .customSelect(
          'SELECT DISTINCT substr(eaten_on, 1, 4) AS y FROM meals ORDER BY y DESC',
        )
        .get();
    return rows
        .map((row) => int.tryParse(row.read<String>('y')))
        .whereType<int>()
        .where((year) => year > 0)
        .toList();
  }

  // ------------------------------------------------------------ export/import

  @override
  Future<MealBundle> exportBundle() async {
    final cuisineRows = await _db.select(_db.cuisines).get();
    final tagRows = await _db.select(_db.tags).get();
    final mealRows = await (_db.select(_db.meals)
          ..orderBy([
            (row) => OrderingTerm.asc(row.eatenOn),
            (row) => OrderingTerm.asc(row.createdAt),
          ]))
        .get();
    return MealBundle(
      formatVersion: MealBundle.currentFormatVersion,
      cuisines: [
        for (final row in cuisineRows)
          BundleCuisine(
            id: row.id,
            name: row.name,
            isBuiltin: row.isBuiltin,
            sortOrder: row.sortOrder,
            archivedAt: row.archivedAt,
          ),
      ],
      tags: [for (final row in tagRows) Tag(id: row.id, name: row.name)],
      meals: await Future.wait(mealRows.map(_hydrate)),
    );
  }

  @override
  Future<ImportSummary> importBundle(MealBundle bundle) async {
    var imported = 0;
    var skipped = 0;
    await _db.transaction(() async {
      for (final cuisine in bundle.cuisines) {
        await _db.into(_db.cuisines).insert(
              CuisinesCompanion.insert(
                id: cuisine.id,
                name: cuisine.name,
                isBuiltin: Value(cuisine.isBuiltin),
                sortOrder: Value(cuisine.sortOrder),
                archivedAt: Value(cuisine.archivedAt),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }

      final tagIdMap = <String, String>{};
      for (final tag in bundle.tags) {
        final normalized = tag.name.toLowerCase();
        final existing = await (_db.select(_db.tags)
              ..where((row) => row.normalizedName.equals(normalized)))
            .getSingleOrNull();
        if (existing != null) {
          tagIdMap[tag.id] = existing.id;
          continue;
        }
        final id = await (_db.select(_db.tags)
              ..where((row) => row.id.equals(tag.id)))
            .getSingleOrNull();
        final newId = id == null ? tag.id : _uuid.v4();
        await _db.into(_db.tags).insert(TagsCompanion.insert(
              id: newId,
              name: tag.name,
              normalizedName: normalized,
              createdAt: _now(),
            ));
        tagIdMap[tag.id] = newId;
      }

      for (final meal in bundle.meals) {
        final clash = await (_db.select(_db.meals)
              ..where((row) => row.id.equals(meal.id)))
            .getSingleOrNull();
        final cuisine = await (_db.select(_db.cuisines)
              ..where((row) => row.id.equals(meal.cuisineId)))
            .getSingleOrNull();
        if (clash != null || cuisine == null) {
          skipped++;
          continue;
        }

        await _db.into(_db.meals).insert(MealsCompanion.insert(
              id: meal.id,
              eatenOn: dateKey(meal.eatenOn),
              slot: Value(meal.slot?.name),
              cityCode: meal.cityCode,
              cuisineId: meal.cuisineId,
              note: Value(meal.note),
              createdAt: meal.createdAt,
              updatedAt: meal.updatedAt,
            ));
        for (final dish in meal.dishes) {
          await _db.into(_db.dishes).insert(DishesCompanion.insert(
                id: dish.id,
                mealId: meal.id,
                name: dish.name,
                position: dish.position,
              ));
        }
        for (final photo in meal.photos) {
          await _db.into(_db.photos).insert(PhotosCompanion.insert(
                id: photo.id,
                mealId: meal.id,
                fileName: photo.fileName,
                thumbName: photo.thumbName,
                width: photo.width,
                height: photo.height,
                position: photo.position,
              ));
        }
        for (final tag in meal.tags) {
          final tagId = tagIdMap[tag.id];
          if (tagId == null) continue;
          await _db.into(_db.mealTags).insert(
                MealTagsCompanion.insert(mealId: meal.id, tagId: tagId),
                mode: InsertMode.insertOrIgnore,
              );
        }
        imported++;
      }
    });
    return ImportSummary(imported: imported, skipped: skipped);
  }

  // ----------------------------------------------------------------- helpers

  Future<Meal> _hydrate(MealRow row) async {
    final dishRows = await (_db.select(_db.dishes)
          ..where((d) => d.mealId.equals(row.id))
          ..orderBy([(d) => OrderingTerm.asc(d.position)]))
        .get();
    final photoRows = await (_db.select(_db.photos)
          ..where((p) => p.mealId.equals(row.id))
          ..orderBy([(p) => OrderingTerm.asc(p.position)]))
        .get();
    final tagRows = await (_db.select(_db.tags).join([
      innerJoin(_db.mealTags, _db.mealTags.tagId.equalsExp(_db.tags.id)),
    ])
          ..where(_db.mealTags.mealId.equals(row.id))
          ..orderBy([OrderingTerm.asc(_db.tags.name)]))
        .get();
    return Meal(
      id: row.id,
      eatenOn: parseDateKey(row.eatenOn),
      slot: MealSlot.fromDb(row.slot),
      cityCode: row.cityCode,
      cuisineId: row.cuisineId,
      note: row.note,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      dishes: dishRows
          .map((d) => Dish(id: d.id, name: d.name, position: d.position))
          .toList(),
      photos: photoRows
          .map((p) => PhotoRef(
                id: p.id,
                fileName: p.fileName,
                thumbName: p.thumbName,
                width: p.width,
                height: p.height,
                position: p.position,
              ))
          .toList(),
      tags: tagRows.map((r) => r.readTable(_db.tags)).map((t) => Tag(id: t.id, name: t.name)).toList(),
    );
  }

  Cuisine _toCuisine(CuisineRow row) => Cuisine(
        id: row.id,
        name: row.name,
        isBuiltin: row.isBuiltin,
        sortOrder: row.sortOrder,
        archivedAt: row.archivedAt,
      );
}
