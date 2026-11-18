import '../data/geo/place_catalog.dart';
import 'meal_repository.dart';

/// 一个省的聚合结果：总餐数与去过的城市数。
class ProvinceAggregate {
  const ProvinceAggregate({
    required this.province,
    required this.mealCount,
    required this.cityCount,
  });

  final Place province;
  final int mealCount;
  final int cityCount;
}

/// 把「城市 → 餐数」提升为「省 → 餐数」。
///
/// 找不到对应城市的记录会被跳过并计入 [unknown]，而不是静默丢掉——
/// 数据集升级后旧城市编码可能失效，这种情况需要能被发现。
class ProvinceAggregation {
  const ProvinceAggregation(this.provinces, {required this.unknownMeals});

  final List<ProvinceAggregate> provinces;
  final int unknownMeals;

  factory ProvinceAggregation.fromCityCounts(
    List<CityCount> counts,
    PlaceCatalog catalog,
  ) {
    final meals = <int, int>{};
    final cities = <int, Set<int>>{};
    var unknown = 0;
    for (final count in counts) {
      final city = catalog.byId(int.tryParse(count.cityCode) ?? -1);
      if (city == null || !city.isCity) {
        unknown += count.count;
        continue;
      }
      final province = catalog.provinceOfCity(city);
      if (province == null) {
        unknown += count.count;
        continue;
      }
      meals[province.id] = (meals[province.id] ?? 0) + count.count;
      cities.putIfAbsent(province.id, () => {}).add(city.id);
    }
    final result = <ProvinceAggregate>[];
    for (final entry in meals.entries) {
      final province = catalog.byId(entry.key);
      if (province == null) continue;
      result.add(
        ProvinceAggregate(
          province: province,
          mealCount: entry.value,
          cityCount: cities[entry.key]?.length ?? 0,
        ),
      );
    }
    result.sort((a, b) => b.mealCount.compareTo(a.mealCount));
    return ProvinceAggregation(result, unknownMeals: unknown);
  }
}
