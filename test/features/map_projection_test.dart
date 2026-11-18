import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealmap/data/geo/place_catalog.dart';
import 'package:mealmap/features/map/city_dot_map.dart';

void main() {
  final catalog = PlaceCatalog.fromJson(
    jsonDecode(File('assets/data/places.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  test('内置点位数量符合预期', () {
    expect(catalog.provinces.length, 34);
    expect(catalog.cities.length, 372);
    expect(catalog.districts.length, 2851);
  });

  test('所有点位都被投影到画布内', () {
    final projection = MapProjection(catalog);
    const size = Size(360, 300);
    final transform = projection.fit(size, const EdgeInsets.all(12));
    for (final place in catalog.all) {
      final offset = transform(projection.of(place));
      expect(offset.dx, inInclusiveRange(0, 360), reason: place.name);
      expect(offset.dy, inInclusiveRange(0, 300), reason: place.name);
    }
  });

  test('方位关系正确：北京在成都东北，三亚在哈尔滨以南', () {
    final projection = MapProjection(catalog);
    final transform = projection.fit(
      const Size(360, 300),
      const EdgeInsets.all(12),
    );
    final chengdu = catalog.byId(5101)!;
    final beijing = catalog.byId(11)!;
    final sanya = catalog.byId(4602)!;
    final harbin = catalog.byId(2301)!;

    final chengduOffset = transform(projection.of(chengdu));
    final beijingOffset = transform(projection.of(beijing));
    expect(beijingOffset.dx, greaterThan(chengduOffset.dx));
    expect(beijingOffset.dy, lessThan(chengduOffset.dy));

    final sanyaOffset = transform(projection.of(sanya));
    final harbinOffset = transform(projection.of(harbin));
    expect(sanyaOffset.dy, greaterThan(harbinOffset.dy));
  });
}
