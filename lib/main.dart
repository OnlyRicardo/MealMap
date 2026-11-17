import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'data/seed/cuisines.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  try {
    await container.read(mealRepositoryProvider).seedCuisines(builtinCuisines);
  } catch (error, stack) {
    // 种子导入失败不应该让 App 打不开；记录后继续，用户仍可手动添加菜系。
    debugPrint('内置菜系导入失败: $error\n$stack');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MealMapApp(),
    ),
  );
}
