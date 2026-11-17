import 'bundle.dart';
import 'models.dart';

/// 领域规则被违反时抛出，UI 负责翻译成用户可读的提示。
class MealMapException implements Exception {
  const MealMapException(this.message);
  final String message;

  @override
  String toString() => message;
}

class InvalidTagNameException extends MealMapException {
  const InvalidTagNameException(super.message);
}

class TagLimitException extends MealMapException {
  const TagLimitException(super.message);
}

class PhotoLimitException extends MealMapException {
  const PhotoLimitException(super.message);
}

class UnknownCuisineException extends MealMapException {
  const UnknownCuisineException(super.message);
}

class CuisineNameConflictException extends MealMapException {
  const CuisineNameConflictException(super.message);
}

/// 城市数量聚合结果（城市到省份的映射由内置数据集负责，不在仓库层）。
class CityCount {
  const CityCount({required this.cityCode, required this.count});

  final String cityCode;
  final int count;
}

class CuisineCount {
  const CuisineCount({required this.cuisineId, required this.count});

  final String cuisineId;
  final int count;
}

/// 读写一餐数据的唯一入口。
///
/// UI 只依赖这个接口，不依赖 drift 的生成类型——这样将来接云同步时
/// 只需要换实现，页面不用动（见 ADR-0002）。
abstract class MealRepository {
  Future<List<Cuisine>> listCuisines({bool includeArchived = false});
  Future<int> seedCuisines(List<CuisineSeed> seeds);
  Future<Cuisine> addCuisine(String name);
  Future<void> renameCuisine(String id, String name);
  Future<void> archiveCuisine(String id);
  Future<void> restoreCuisine(String id);

  Future<List<Tag>> listTags();
  Future<Tag> upsertTag(String name);
  Future<void> renameTag(String id, String name);

  /// 把 [fromId] 合并进 [intoId]：引用关系转移，然后删除 [fromId]。
  Future<void> mergeTags(String fromId, String intoId);
  Future<void> deleteTag(String id);

  Future<List<Meal>> mealsOn(DateTime date);

  /// 闭区间 [from] 到 [to]（都只取日期部分），按日期、创建时间升序。
  Future<List<Meal>> mealsBetween(DateTime from, DateTime to);
  Future<Meal?> mealById(String id);
  Future<Meal> saveMeal(MealDraft draft);
  Future<void> deleteMeal(String id);

  /// 按城市聚合；[year] 为 null 表示全部年份。
  Future<List<CityCount>> cityCounts({int? year});

  /// 按菜系聚合；[year] 为 null 表示全部年份。
  Future<List<CuisineCount>> cuisineCounts({int? year});

  /// 有记录的年份，倒序。用于地图年份切换。
  Future<List<int>> yearsWithMeals();

  /// 导出全部数据（不含照片二进制）。
  Future<MealBundle> exportBundle();

  /// 合并导入：ID 冲突的 Meal 会被跳过而不是覆盖。
  Future<ImportSummary> importBundle(MealBundle bundle);
}
