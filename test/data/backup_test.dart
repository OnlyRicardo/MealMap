import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealmap/data/backup_service.dart';
import 'package:mealmap/data/db/database.dart';
import 'package:mealmap/data/drift_meal_repository.dart';
import 'package:mealmap/data/seed/cuisines.dart';
import 'package:mealmap/domain/bundle.dart';
import 'package:mealmap/domain/meal_repository.dart';
import 'package:mealmap/domain/models.dart';
import 'package:mealmap/domain/photo_store.dart';

/// 内存版文件系统，够备份服务用。
class _MemoryPhotoStore implements PhotoFileStore {
  final files = <String, List<int>>{};

  @override
  Future<void> delete(String fileName) async => files.remove(fileName);

  @override
  Future<String> pathOf(String fileName) async => '/mem/$fileName';

  @override
  Future<String> imagesDirPath() async => '/mem';

  @override
  Future<List<int>?> read(String fileName) async => files[fileName];

  @override
  Future<void> write(String fileName, List<int> bytes) async =>
      files[fileName] = bytes;
}

void main() {
  late Directory temp;
  late AppDatabase db;
  late _MemoryPhotoStore store;
  late DriftMealRepository repo;
  late BackupService backup;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('mealmap_backup_test');
    db = AppDatabase(NativeDatabase.memory());
    store = _MemoryPhotoStore();
    repo = DriftMealRepository(db, store);
    backup = BackupService(repo, store);
    await repo.seedCuisines(builtinCuisines);
  });

  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  Future<String> export() async {
    final file = await backup.writeArchive(path: '${temp.path}/backup.zip');
    return file.path;
  }

  test('导出再导入到空库：数据、标签、照片都回来了', () async {
    store.files['p1.jpg'] = [1, 2, 3];
    store.files['t_p1.jpg'] = [4, 5];
    final meal = await repo.saveMeal(MealDraft(
      eatenOn: DateTime(2026, 5, 4),
      slot: MealSlot.dinner,
      cityCode: '510100',
      cuisineId: 'sichuan',
      note: '好吃',
      dishes: ['麻婆豆腐'],
      photos: [
        const PhotoDraft(
          fileName: 'p1.jpg',
          thumbName: 't_p1.jpg',
          width: 2048,
          height: 1536,
          position: 0,
        ),
      ],
      tagNames: ['火锅'],
    ));
    final zipPath = await export();

    // 新设备：空库 + 空文件系统
    final db2 = AppDatabase(NativeDatabase.memory());
    addTearDown(db2.close);
    final store2 = _MemoryPhotoStore();
    final repo2 = DriftMealRepository(db2, store2);
    final backup2 = BackupService(repo2, store2);

    final summary = await backup2.importArchive(zipPath);
    expect(summary.imported, 1);
    expect(summary.skipped, 0);

    final restored = await repo2.mealById(meal.id);
    expect(restored, isNotNull);
    expect(restored!.eatenOn, DateTime(2026, 5, 4));
    expect(restored.slot, MealSlot.dinner);
    expect(restored.note, '好吃');
    expect(restored.dishes.single.name, '麻婆豆腐');
    expect(restored.tags.single.name, '火锅');
    expect(restored.photos.single.fileName, 'p1.jpg');

    expect(store2.files['p1.jpg'], [1, 2, 3]);
    expect(store2.files['t_p1.jpg'], [4, 5]);

    final cuisines = await repo2.listCuisines();
    expect(cuisines.map((c) => c.id), contains('sichuan'));
  });

  test('重复导入同一份备份时跳过而不是覆盖', () async {
    await repo.saveMeal(MealDraft(
      eatenOn: DateTime(2026, 5, 4),
      cityCode: '510100',
      cuisineId: 'sichuan',
    ));
    final zipPath = await export();

    final first = await backup.importArchive(zipPath);
    expect(first.imported, 0);
    expect(first.skipped, 1);

    expect((await repo.mealsBetween(DateTime(2026, 5, 4), DateTime(2026, 5, 4))), hasLength(1));
  });

  test('版本比当前新时拒绝导入且不写入任何数据', () async {
    final archive = Archive()
      ..addFile(ArchiveFile.bytes(
        'data.json',
        utf8.encode(jsonEncode({
          'formatVersion': MealBundle.currentFormatVersion + 1,
          'cuisines': const [],
          'tags': const [],
          'meals': const [],
        })),
      ));
    final path = '${temp.path}/future.zip';
    await File(path).writeAsBytes(ZipEncoder().encodeBytes(archive));

    expect(
      () => backup.importArchive(path),
      throwsA(isA<MealMapException>()),
    );
    expect(await repo.listCuisines(), hasLength(builtinCuisines.length));
  });

  test('不是 zip 或缺少 data.json 时报可读错误', () async {
    final notZip = '${temp.path}/bad.zip';
    await File(notZip).writeAsBytes([1, 2, 3, 4]);
    expect(() => backup.importArchive(notZip), throwsA(isA<Exception>()));

    final empty = Archive()..addFile(ArchiveFile.bytes('readme.txt', [1]));
    final missing = '${temp.path}/missing.zip';
    await File(missing).writeAsBytes(ZipEncoder().encodeBytes(empty));
    expect(
      () => backup.importArchive(missing),
      throwsA(isA<MealMapException>()),
    );
  });
}
