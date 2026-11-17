/// 领域模型：不依赖 drift、不依赖 Flutter。
///
/// 照片只保存文件名，绝不保存绝对路径——私有目录在不同设备/安装上不同。
library;

enum MealSlot {
  breakfast,
  lunch,
  dinner,
  snack;

  static MealSlot? fromDb(String? value) {
    if (value == null) return null;
    for (final slot in MealSlot.values) {
      if (slot.name == value) return slot;
    }
    return null;
  }
}

class Cuisine {
  const Cuisine({
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

  bool get isArchived => archivedAt != null;
}

class Tag {
  const Tag({required this.id, required this.name});

  final String id;
  final String name;
}

/// 内置菜系的种子数据。ID 用稳定 slug，便于将来做国际化与云同步。
class CuisineSeed {
  const CuisineSeed({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final int sortOrder;
}

class Dish {
  const Dish({required this.id, required this.name, required this.position});

  final String id;
  final String name;
  final int position;
}

class PhotoRef {
  const PhotoRef({
    required this.id,
    required this.fileName,
    required this.thumbName,
    required this.width,
    required this.height,
    required this.position,
  });

  final String id;
  final String fileName;
  final String thumbName;
  final int width;
  final int height;
  final int position;
}

class Meal {
  const Meal({
    required this.id,
    required this.eatenOn,
    required this.cityCode,
    required this.cuisineId,
    required this.createdAt,
    required this.updatedAt,
    this.slot,
    this.note,
    this.dishes = const [],
    this.photos = const [],
    this.tags = const [],
  });

  final String id;

  /// 只保留年月日，时间部分恒为 00:00（本地时区）。
  final DateTime eatenOn;
  final MealSlot? slot;
  final String cityCode;
  final String cuisineId;
  final String? note;
  final List<Dish> dishes;
  final List<PhotoRef> photos;
  final List<Tag> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class PhotoDraft {
  const PhotoDraft({
    required this.fileName,
    required this.thumbName,
    required this.width,
    required this.height,
    required this.position,
    this.id,
  });

  final String? id;
  final String fileName;
  final String thumbName;
  final int width;
  final int height;
  final int position;
}

class MealDraft {
  const MealDraft({
    required this.eatenOn,
    required this.cityCode,
    required this.cuisineId,
    this.id,
    this.slot,
    this.note,
    this.dishes = const [],
    this.photos = const [],
    this.tagNames = const [],
  });

  final String? id;
  final DateTime eatenOn;
  final MealSlot? slot;
  final String cityCode;
  final String cuisineId;
  final String? note;
  final List<String> dishes;
  final List<PhotoDraft> photos;
  final List<String> tagNames;
}

/// 日期键：`yyyy-MM-dd`，避免把时区问题带进数据库。
String dateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime parseDateKey(String key) {
  final parts = key.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
