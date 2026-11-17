import 'package:drift/drift.dart';

part 'database.g.dart';

@DataClassName('CuisineRow')
class Cuisines extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get isBuiltin => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MealRow')
class Meals extends Table {
  TextColumn get id => text()();

  /// `yyyy-MM-dd`，刻意用文本存日期，避免时区把「昨天」变成「今天」。
  TextColumn get eatenOn => text()();
  TextColumn get slot => text().nullable()();
  TextColumn get cityCode => text()();
  TextColumn get cuisineId => text().references(Cuisines, #id)();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DishRow')
class Dishes extends Table {
  TextColumn get id => text()();
  TextColumn get mealId =>
      text().references(Meals, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PhotoRow')
class Photos extends Table {
  TextColumn get id => text()();
  TextColumn get mealId =>
      text().references(Meals, #id, onDelete: KeyAction.cascade)();
  TextColumn get fileName => text()();
  TextColumn get thumbName => text()();
  IntColumn get width => integer()();
  IntColumn get height => integer()();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TagRow')
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// 归一化后的比较键（小写），保证「火锅」与「火锅 」不会变成两个标签。
  TextColumn get normalizedName => text().unique()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MealTagRow')
class MealTags extends Table {
  TextColumn get mealId =>
      text().references(Meals, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {mealId, tagId};
}

@DriftDatabase(tables: [Cuisines, Meals, Dishes, Photos, Tags, MealTags])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement('CREATE INDEX meals_eaten_on ON meals(eaten_on)');
      await customStatement('CREATE INDEX meals_city ON meals(city_code)');
      await customStatement('CREATE INDEX meals_cuisine ON meals(cuisine_id)');
      await customStatement('CREATE INDEX photos_meal ON photos(meal_id)');
      await customStatement('CREATE INDEX dishes_meal ON dishes(meal_id)');
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
