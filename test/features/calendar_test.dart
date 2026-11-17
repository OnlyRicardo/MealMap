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
import 'package:mealmap/features/calendar/calendar_screen.dart';

class _NoopPhotoStore implements PhotoFileStore {
  @override
  Future<void> delete(String fileName) async {}

  @override
  Future<String> pathOf(String fileName) async => '/tmp/$fileName';

  @override
  Future<String> imagesDirPath() async => '/tmp';

  @override
  Future<List<int>?> read(String fileName) async => null;

  @override
  Future<void> write(String fileName, List<int> bytes) async {}

}

const _places = {
  'v': 1,
  'places': [
    [51, 0, 0, '四川', 104.0765, 30.6517],
    [5101, 51, 1, '成都', 104.0663, 30.5730],
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

  Future<void> pumpCalendar(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealRepositoryProvider.overrideWithValue(repo),
          placeCatalogProvider.overrideWith(
            (ref) async => PlaceCatalog.fromJson(_places),
          ),
        ],
        child: const MaterialApp(home: CalendarScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('月视图显示当天餐数与菜系色点，点开可在弹层里进入详情', (tester) async {
    final now = DateTime.now();
    final today = dateOnly(now);
    await repo.saveMeal(MealDraft(
      eatenOn: today,
      cityCode: '5101',
      cuisineId: 'sichuan',
      dishes: ['麻婆豆腐'],
    ));
    await repo.saveMeal(MealDraft(
      eatenOn: today,
      cityCode: '4403',
      cuisineId: 'cantonese',
    ));

    await pumpCalendar(tester);

    expect(find.text('${now.year}年${now.month}月'), findsOneWidget);
    expect(find.text('共 2 餐'), findsOneWidget);

    // 点当天格子
    await tester.tap(find.text('${today.day}'));
    await tester.pumpAndSettle();

    expect(find.text('${today.month}月${today.day}日 · 2 餐'), findsOneWidget);
    expect(find.textContaining('麻婆豆腐'), findsOneWidget);
    expect(find.text('川菜'), findsOneWidget);
  });

  testWidgets('年视图是只读热力图，点击格子不弹窗', (tester) async {
    final now = DateTime.now();
    await repo.saveMeal(MealDraft(
      eatenOn: DateTime(now.year, 1, 5),
      cityCode: '5101',
      cuisineId: 'sichuan',
    ));

    await pumpCalendar(tester);

    await tester.tap(find.byTooltip('年视图'));
    await tester.pumpAndSettle();

    expect(find.text('1 月'), findsOneWidget);
    expect(find.text('12 月'), findsOneWidget);

    // 热力图没有可点区域
    await tester.tap(find.text('1 月'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });
}
