import 'package:flutter_test/flutter_test.dart';
import 'package:mealmap/data/geo/place_catalog.dart';
import 'package:mealmap/domain/map_aggregation.dart';
import 'package:mealmap/domain/meal_repository.dart';

const _fixture = {
  'v': 1,
  'places': [
    [51, 0, 0, '四川', 104.0765, 30.6517],
    [5101, 51, 1, '成都', 104.0663, 30.5730],
    [5107, 51, 1, '绵阳', 104.6796, 31.4675],
    [510107, 5101, 2, '武侯', 104.0433, 30.6419],
    [44, 0, 0, '广东', 113.2665, 23.1322],
    [4403, 44, 1, '深圳', 114.0579, 22.5435],
  ],
};

void main() {
  final catalog = PlaceCatalog.fromJson(_fixture);

  test('按层级提供省 / 市 / 区县', () {
    expect(catalog.provinces.map((p) => p.name), ['四川', '广东']);
    expect(catalog.citiesOf(51).map((p) => p.name), ['成都', '绵阳']);
    expect(catalog.districtsOf(5101).map((p) => p.name), ['武侯']);
    expect(catalog.provinceOfCity(catalog.byId(4403)!)!.name, '广东');
  });

  test('城市聚合提升到省，并按餐数排序', () {
    final agg = ProvinceAggregation.fromCityCounts(const [
      CityCount(cityCode: '5101', count: 3),
      CityCount(cityCode: '5107', count: 1),
      CityCount(cityCode: '4403', count: 2),
    ], catalog);

    expect(agg.unknownMeals, 0);
    expect(agg.provinces.map((p) => p.province.name), ['四川', '广东']);
    expect(agg.provinces.first.mealCount, 4);
    expect(agg.provinces.first.cityCount, 2);
    expect(agg.provinces.last.cityCount, 1);
  });

  test('未知城市编码被计为 unknown，而不是静默丢弃', () {
    final agg = ProvinceAggregation.fromCityCounts(const [
      CityCount(cityCode: '9999', count: 2),
      CityCount(cityCode: '5101', count: 1),
    ], catalog);

    expect(agg.unknownMeals, 2);
    expect(agg.provinces.single.mealCount, 1);
  });
}
