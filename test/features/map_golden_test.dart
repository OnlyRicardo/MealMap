import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealmap/data/geo/place_catalog.dart';
import 'package:mealmap/features/map/city_dot_map.dart';

/// 点阵地图没有文字，适合做 golden：字形不影响结果。
void main() {
  final catalog = PlaceCatalog.fromJson(
    jsonDecode(File('assets/data/places.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  testWidgets('点阵地图轮廓与数量着色', (tester) async {
    tester.view.physicalSize = const Size(400, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE8590C)),
        ),
        home: Scaffold(
          body: CityDotMap(
            catalog: catalog,
            counts: const {5101: 5, 4403: 2, 1101: 1, 3101: 3, 3301: 1},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(CityDotMap),
      matchesGoldenFile('goldens/city_dot_map.png'),
    );
  });
}
