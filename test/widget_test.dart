import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealmap/app/app.dart';
import 'package:mealmap/app/providers.dart';
import 'package:mealmap/data/db/database.dart';
import 'package:mealmap/data/drift_meal_repository.dart';
import 'package:mealmap/domain/photo_store.dart';

class _NoopPhotoStore implements PhotoFileStore {
  @override
  Future<void> delete(String fileName) async {}
}

void main() {
  testWidgets('没有记录时首页显示空状态', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftMealRepository(db, photoStore: _NoopPhotoStore());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [mealRepositoryProvider.overrideWithValue(repo)],
        child: const MealMapApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('美食地图'), findsOneWidget);
    expect(find.textContaining('还没有记录'), findsOneWidget);
    expect(find.text('记一餐'), findsOneWidget);
  });
}
