import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealmap/app/providers.dart';
import 'package:mealmap/data/db/database.dart';
import 'package:mealmap/data/drift_meal_repository.dart';
import 'package:mealmap/data/geo/place_catalog.dart';
import 'package:mealmap/domain/models.dart';
import 'package:mealmap/domain/photo_store.dart';
import 'package:mealmap/features/meal/meal_form_screen.dart';

class _NoopPhotoStore implements PhotoFileStore {
  @override
  Future<void> delete(String fileName) async {}
}

const _places = {
  'v': 1,
  'places': [
    [51, 0, 0, '四川', 104.0765, 30.6517],
    [5101, 51, 1, '成都', 104.0663, 30.5730],
    [5107, 51, 1, '绵阳', 104.6796, 31.4675],
    [44, 0, 0, '广东', 113.2665, 23.1322],
    [4403, 44, 1, '深圳', 114.0579, 22.5435],
  ],
};

void main() {
  late AppDatabase db;
  late DriftMealRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftMealRepository(db, _NoopPhotoStore());
    await repo.seedCuisines(const [
      CuisineSeed(id: 'sichuan', name: '川菜', sortOrder: 10),
      CuisineSeed(id: 'cantonese', name: '粤菜', sortOrder: 20),
    ]);
  });

  tearDown(() => db.close());

  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealRepositoryProvider.overrideWithValue(repo),
          placeCatalogProvider.overrideWith(
            (ref) async => PlaceCatalog.fromJson(_places),
          ),
        ],
        child: const MaterialApp(home: MealFormScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('选城市、菜系后保存，记录落到当天', (tester) async {
    await pumpForm(tester);

    // 省 → 市
    await tester.tap(find.text('选择城市'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('四川'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('成都'));
    await tester.pumpAndSettle();
    expect(find.text('成都'), findsOneWidget);

    // 菜系
    await tester.tap(find.text('川菜'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    final meals = await repo.mealsOn(DateTime.now());
    expect(meals, hasLength(1));
    expect(meals.single.cityCode, '5101');
    expect(meals.single.cuisineId, 'sichuan');
    expect(meals.single.slot, isNull);
  });

  testWidgets('没选城市就保存会被拦截', (tester) async {
    await pumpForm(tester);

    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('请选择城市'), findsOneWidget);
    expect(await repo.mealsOn(DateTime.now()), isEmpty);
  });

  testWidgets('标签长度与上限在表单层就被拦截', (tester) async {
    await pumpForm(tester);

    final tagField = find.widgetWithText(TextField, '2–12 个字，回车添加');
    await tester.scrollUntilVisible(
      tagField,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(tagField, '火');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('标签需要 2–12 个字'), findsOneWidget);

    await tester.enterText(tagField, '火锅');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, '火锅'), findsOneWidget);
  });
}
