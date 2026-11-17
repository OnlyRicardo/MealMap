import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealmap/data/db/database.dart';
import 'package:mealmap/data/drift_meal_repository.dart';
import 'package:mealmap/domain/meal_repository.dart';
import 'package:mealmap/data/seed/cuisines.dart';
import 'package:mealmap/domain/models.dart';
import 'package:mealmap/domain/rules.dart';
import 'package:mealmap/domain/photo_store.dart';

class _FakePhotoStore implements PhotoFileStore {
  final deleted = <String>[];

  @override
  Future<void> delete(String fileName) async => deleted.add(fileName);

  @override
  Future<String> pathOf(String fileName) async => '/tmp/$fileName';

  @override
  Future<String> imagesDirPath() async => '/tmp';

}

void main() {
  late AppDatabase db;
  late _FakePhotoStore files;
  late DriftMealRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    files = _FakePhotoStore();
    repo = DriftMealRepository(
      db,
      files,
      now: () => DateTime(2026, 11, 17, 20, 0),
    );
  });

  tearDown(() => db.close());

  PhotoDraft photo(int i, {String? id}) => PhotoDraft(
        id: id,
        fileName: 'img_$i.jpg',
        thumbName: 'thumb_$i.jpg',
        width: 2048,
        height: 1536,
        position: i,
      );

  Future<Cuisine> seedCuisine([String name = '川菜']) => repo.addCuisine(name);

  test('保存一餐后能完整读回菜品、照片与标签', () async {
    final cuisine = await seedCuisine();
    final meal = await repo.saveMeal(MealDraft(
      eatenOn: DateTime(2026, 11, 17),
      slot: MealSlot.dinner,
      cityCode: '510100',
      cuisineId: cuisine.id,
      note: '和朋友',
      dishes: ['麻婆豆腐', '回锅肉'],
      photos: [photo(0), photo(1)],
      tagNames: ['火锅', '聚餐'],
    ));

    expect(meal.eatenOn, DateTime(2026, 11, 17));
    expect(meal.slot, MealSlot.dinner);
    expect(meal.dishes.map((d) => d.name), ['麻婆豆腐', '回锅肉']);
    expect(meal.photos.length, 2);
    expect(meal.tags.map((t) => t.name), containsAll(['火锅', '聚餐']));

    final sameDay = await repo.mealsOn(DateTime(2026, 11, 17, 23, 59));
    expect(sameDay.map((m) => m.id), [meal.id]);
    final otherDay = await repo.mealsOn(DateTime(2026, 11, 18));
    expect(otherDay, isEmpty);
  });

  test('删除一餐会级联删除子表并清理照片文件', () async {
    final cuisine = await seedCuisine();
    final meal = await repo.saveMeal(MealDraft(
      eatenOn: DateTime(2026, 11, 17),
      cityCode: '510100',
      cuisineId: cuisine.id,
      dishes: ['回锅肉'],
      photos: [photo(0), photo(1)],
      tagNames: ['聚餐'],
    ));

    await repo.deleteMeal(meal.id);

    expect(await repo.mealById(meal.id), isNull);
    expect(await db.select(db.dishes).get(), isEmpty);
    expect(await db.select(db.photos).get(), isEmpty);
    expect(await db.select(db.mealTags).get(), isEmpty);
    expect(files.deleted, containsAll(['img_0.jpg', 'thumb_0.jpg', 'img_1.jpg', 'thumb_1.jpg']));
  });

  test('编辑时移除的照片会被删除，保留的不会被删', () async {
    final cuisine = await seedCuisine();
    final meal = await repo.saveMeal(MealDraft(
      eatenOn: DateTime(2026, 11, 17),
      cityCode: '510100',
      cuisineId: cuisine.id,
      photos: [photo(0), photo(1)],
    ));

    await repo.saveMeal(MealDraft(
      id: meal.id,
      eatenOn: DateTime(2026, 11, 17),
      cityCode: '510100',
      cuisineId: cuisine.id,
      photos: [photo(1)],
    ));

    expect(files.deleted, containsAll(['img_0.jpg', 'thumb_0.jpg']));
    expect(files.deleted, isNot(contains('img_1.jpg')));
    expect((await repo.mealById(meal.id))!.photos.single.fileName, 'img_1.jpg');
  });

  test('标签规则：长度、去重、同名复用、单餐上限', () async {
    final cuisine = await seedCuisine();
    final a = await repo.upsertTag('  火锅  ');
    final b = await repo.upsertTag('火锅');
    expect(a.id, b.id);
    expect(a.name, '火锅');

    expect(() => repo.upsertTag('火'), throwsA(isA<InvalidTagNameException>()));
    final thirteen = '这' * 13;
    expect(() => repo.upsertTag(thirteen), throwsA(isA<InvalidTagNameException>()));

    final tooMany = List.generate(kMaxTagsPerMeal + 1, (i) => '标签$i');
    expect(
      () => repo.saveMeal(MealDraft(
        eatenOn: DateTime(2026, 11, 17),
        cityCode: '510100',
        cuisineId: cuisine.id,
        tagNames: tooMany,
      )),
      throwsA(isA<TagLimitException>()),
    );
  });

  test('单餐照片上限为 9 张', () async {
    final cuisine = await seedCuisine();
    expect(
      () => repo.saveMeal(MealDraft(
        eatenOn: DateTime(2026, 11, 17),
        cityCode: '510100',
        cuisineId: cuisine.id,
        photos: List.generate(kMaxPhotosPerMeal + 1, photo),
      )),
      throwsA(isA<PhotoLimitException>()),
    );
  });

  test('归档菜系不出现在选择列表，但历史记录仍可读', () async {
    final cuisine = await seedCuisine();
    final meal = await repo.saveMeal(MealDraft(
      eatenOn: DateTime(2026, 11, 17),
      cityCode: '510100',
      cuisineId: cuisine.id,
    ));

    await repo.archiveCuisine(cuisine.id);

    expect((await repo.listCuisines()).map((c) => c.id), isNot(contains(cuisine.id)));
    expect(
      (await repo.listCuisines(includeArchived: true)).map((c) => c.id),
      contains(cuisine.id),
    );
    expect((await repo.mealById(meal.id))!.cuisineId, cuisine.id);
  });

  test('菜系重名会被拒绝（忽略大小写）', () async {
    await seedCuisine('Ramen');
    expect(() => seedCuisine('ramen'), throwsA(isA<CuisineNameConflictException>()));
  });

  test('内置菜系种子幂等，且不影响已有自定义菜系', () async {
    final custom = await repo.addCuisine('我妈做的菜');

    final first = await repo.seedCuisines(builtinCuisines);
    final second = await repo.seedCuisines(builtinCuisines);

    expect(first, builtinCuisines.length);
    expect(second, 0);
    final all = await repo.listCuisines();
    expect(all.length, builtinCuisines.length + 1);
    expect(all.map((c) => c.id), contains(custom.id));
    expect(all.where((c) => c.isBuiltin).length, builtinCuisines.length);
    // 排序：内置的按 sortOrder，自定义的排在其后
    expect(all.first.id, 'sichuan');
    expect(all.last.id, custom.id);
  });

  test('城市与菜系聚合支持按年份筛选', () async {
    final sichuan = await seedCuisine('川菜');
    final cantonese = await seedCuisine('粤菜');
    await repo.saveMeal(MealDraft(
      eatenOn: DateTime(2025, 12, 31),
      cityCode: '510100',
      cuisineId: sichuan.id,
    ));
    await repo.saveMeal(MealDraft(
      eatenOn: DateTime(2026, 1, 1),
      cityCode: '510100',
      cuisineId: cantonese.id,
    ));
    await repo.saveMeal(MealDraft(
      eatenOn: DateTime(2026, 5, 1),
      cityCode: '440300',
      cuisineId: cantonese.id,
    ));

    final allCities = await repo.cityCounts();
    expect(
      {for (final c in allCities) c.cityCode: c.count},
      {'510100': 2, '440300': 1},
    );
    final thisYear = await repo.cityCounts(year: 2026);
    expect(
      {for (final c in thisYear) c.cityCode: c.count},
      {'510100': 1, '440300': 1},
    );
    expect(await repo.yearsWithMeals(), [2026, 2025]);
    final cuisines = await repo.cuisineCounts(year: 2026);
    expect(
      {for (final c in cuisines) c.cuisineId: c.count},
      {sichuan.id: 0, cantonese.id: 2}.map((k, v) => MapEntry(k, v))..removeWhere((_, v) => v == 0),
    );
  });
}
