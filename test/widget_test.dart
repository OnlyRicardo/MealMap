import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealmap/app/app.dart';
import 'package:mealmap/app/providers.dart';
import 'package:mealmap/data/db/database.dart';
import 'package:mealmap/data/drift_meal_repository.dart';
import 'package:mealmap/data/geo/place_catalog.dart';
import 'package:mealmap/domain/photo_store.dart';

class _NoopPhotoStore implements PhotoFileStore {
  @override
  Future<void> delete(String fileName) async {}
}

const _places = {
  'v': 1,
  'places': [
    [51, 0, 0, '四川', 104.0765, 30.6517],
    [5101, 51, 1, '成都', 104.0663, 30.5730],
    [510107, 5101, 2, '武侯', 104.0433, 30.6419],
    [44, 0, 0, '广东', 113.2665, 23.1322],
    [4403, 44, 1, '深圳', 114.0579, 22.5435],
  ],
};

void main() {
  testWidgets('没有记录时首页显示地图与引导文案', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftMealRepository(db, _NoopPhotoStore());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealRepositoryProvider.overrideWithValue(repo),
          placeCatalogProvider.overrideWith(
            (ref) async => PlaceCatalog.fromJson(_places),
          ),
        ],
        child: const MealMapApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('美食地图'), findsOneWidget);
    expect(find.textContaining('还没有记录'), findsOneWidget);
    expect(find.text('记一餐'), findsOneWidget);
    expect(find.text('全部年份'), findsOneWidget);
  });
}
