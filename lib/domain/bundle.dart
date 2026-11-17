import 'models.dart';

/// 导出/导入的完整数据包（不含照片二进制；照片由备份服务按文件名处理）。
///
/// `formatVersion` 变更时导入端必须拒绝或迁移，见 spec §9。
class MealBundle {
  const MealBundle({
    required this.formatVersion,
    required this.cuisines,
    required this.tags,
    required this.meals,
  });

  static const int currentFormatVersion = 1;

  final int formatVersion;
  final List<BundleCuisine> cuisines;
  final List<Tag> tags;
  final List<Meal> meals;
}

class BundleCuisine {
  const BundleCuisine({
    required this.id,
    required this.name,
    required this.isBuiltin,
    required this.sortOrder,
    this.archivedAt,
  });

  final String id;
  final String name;
  final bool isBuiltin;
  final int sortOrder;
  final DateTime? archivedAt;
}

class ImportSummary {
  const ImportSummary({required this.imported, required this.skipped});

  final int imported;
  final int skipped;
}
