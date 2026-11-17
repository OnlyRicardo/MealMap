import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/bundle.dart';
import '../domain/meal_repository.dart';
import '../domain/models.dart';
import '../domain/photo_store.dart';

/// 一键移机：把数据 + 照片打成一个 zip，通过系统分享发出去；新机导入同一个 zip。
///
/// App 自身不联网，传输交给系统的分享面板（见 spec §9）。
class BackupService {
  BackupService(this._repository, this._photoStore);

  static const String dataEntry = 'data.json';
  static const String photoPrefix = 'photos/';
  static const String thumbPrefix = 'thumbs/';

  final MealRepository _repository;
  final PhotoFileStore _photoStore;

  Future<File> writeArchive({required String path}) async {
    final bundle = await _repository.exportBundle();
    final archive = Archive()
      ..addFile(ArchiveFile.bytes(
        dataEntry,
        utf8.encode(jsonEncode(_bundleToJson(bundle))),
      ));

    final seen = <String>{};
    for (final meal in bundle.meals) {
      for (final photo in meal.photos) {
        if (seen.add(photo.fileName)) {
          final bytes = await _photoStore.read(photo.fileName);
          if (bytes != null) {
            archive.addFile(ArchiveFile.bytes('$photoPrefix${photo.fileName}', bytes));
          }
        }
        if (seen.add(photo.thumbName)) {
          final bytes = await _photoStore.read(photo.thumbName);
          if (bytes != null) {
            archive.addFile(ArchiveFile.bytes('$thumbPrefix${photo.thumbName}', bytes));
          }
        }
      }
    }

    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(ZipEncoder().encodeBytes(archive), flush: true);
    return file;
  }

  /// 生成备份并调用系统分享面板。
  Future<void> exportAndShare() async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now();
    final name = 'mealmap-${stamp.year}'
        '${stamp.month.toString().padLeft(2, '0')}'
        '${stamp.day.toString().padLeft(2, '0')}-'
        '${stamp.hour.toString().padLeft(2, '0')}'
        '${stamp.minute.toString().padLeft(2, '0')}.zip';
    final file = await writeArchive(path: '${dir.path}/$name');
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/zip')],
        text: 'MealMap 备份',
      ),
    );
  }

  /// 导入 zip。先落照片再写数据库；数据先校验版本再提交，避免写进去一半。
  Future<ImportSummary> importArchive(String path) async {
    final bytes = await File(path).readAsBytes();
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } on ArchiveException catch (error) {
      throw MealMapException('无法读取备份文件：${error.message}');
    }
    final dataFile = archive.findFile(dataEntry);
    if (dataFile == null) {
      throw const MealMapException('这不是 MealMap 的备份（缺少 data.json）');
    }
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(dataFile.content)) as Map<String, dynamic>;
    } catch (error) {
      throw MealMapException('备份内容损坏：$error');
    }

    final version = json['formatVersion'];
    if (version is! int || version > MealBundle.currentFormatVersion) {
      throw MealMapException(
        '备份版本（$version）比当前 App 新，请先升级 App 再导入',
      );
    }
    final bundle = _bundleFromJson(json);

    for (final file in archive.files) {
      if (!file.isFile) continue;
      if (file.name.startsWith(photoPrefix)) {
        await _photoStore.write(
          file.name.substring(photoPrefix.length),
          file.content,
        );
      } else if (file.name.startsWith(thumbPrefix)) {
        await _photoStore.write(
          file.name.substring(thumbPrefix.length),
          file.content,
        );
      }
    }

    return _repository.importBundle(bundle);
  }

  // ------------------------------------------------------------------- json

  Map<String, dynamic> _bundleToJson(MealBundle bundle) {
    return {
      'app': 'mealmap',
      'formatVersion': bundle.formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'cuisines': [
        for (final cuisine in bundle.cuisines)
          {
            'id': cuisine.id,
            'name': cuisine.name,
            'isBuiltin': cuisine.isBuiltin,
            'sortOrder': cuisine.sortOrder,
            'archivedAt': cuisine.archivedAt?.toIso8601String(),
          },
      ],
      'tags': [
        for (final tag in bundle.tags) {'id': tag.id, 'name': tag.name},
      ],
      'meals': [
        for (final meal in bundle.meals)
          {
            'id': meal.id,
            'eatenOn': dateKey(meal.eatenOn),
            'slot': meal.slot?.name,
            'cityCode': meal.cityCode,
            'cuisineId': meal.cuisineId,
            'note': meal.note,
            'createdAt': meal.createdAt.toIso8601String(),
            'updatedAt': meal.updatedAt.toIso8601String(),
            'dishes': [
              for (final dish in meal.dishes)
                {'id': dish.id, 'name': dish.name, 'position': dish.position},
            ],
            'photos': [
              for (final photo in meal.photos)
                {
                  'id': photo.id,
                  'fileName': photo.fileName,
                  'thumbName': photo.thumbName,
                  'width': photo.width,
                  'height': photo.height,
                  'position': photo.position,
                },
            ],
            'tagIds': [for (final tag in meal.tags) tag.id],
          },
      ],
    };
  }

  MealBundle _bundleFromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> mapList(Object? value) =>
        (value as List? ?? const []).cast<Map<String, dynamic>>();

    final tags = [
      for (final item in mapList(json['tags']))
        Tag(id: item['id'] as String, name: item['name'] as String),
    ];
    final tagById = {for (final tag in tags) tag.id: tag};

    final cuisines = [
      for (final item in mapList(json['cuisines']))
        BundleCuisine(
          id: item['id'] as String,
          name: item['name'] as String,
          isBuiltin: item['isBuiltin'] as bool? ?? false,
          sortOrder: item['sortOrder'] as int? ?? 0,
          archivedAt: item['archivedAt'] == null
              ? null
              : DateTime.parse(item['archivedAt'] as String),
        ),
    ];

    final meals = [
      for (final item in mapList(json['meals']))
        Meal(
          id: item['id'] as String,
          eatenOn: parseDateKey(item['eatenOn'] as String),
          slot: MealSlot.fromDb(item['slot'] as String?),
          cityCode: item['cityCode'] as String,
          cuisineId: item['cuisineId'] as String,
          note: item['note'] as String?,
          createdAt: DateTime.parse(item['createdAt'] as String),
          updatedAt: DateTime.parse(item['updatedAt'] as String),
          dishes: [
            for (final dish in mapList(item['dishes']))
              Dish(
                id: dish['id'] as String,
                name: dish['name'] as String,
                position: dish['position'] as int? ?? 0,
              ),
          ],
          photos: [
            for (final photo in mapList(item['photos']))
              PhotoRef(
                id: photo['id'] as String,
                fileName: photo['fileName'] as String,
                thumbName: photo['thumbName'] as String,
                width: photo['width'] as int? ?? 0,
                height: photo['height'] as int? ?? 0,
                position: photo['position'] as int? ?? 0,
              ),
          ],
          tags: [
            for (final id in (item['tagIds'] as List? ?? const []).cast<String>())
              if (tagById[id] != null) tagById[id]!,
          ],
        ),
    ];

    return MealBundle(
      formatVersion: json['formatVersion'] as int? ?? 1,
      cuisines: cuisines,
      tags: tags,
      meals: meals,
    );
  }
}
