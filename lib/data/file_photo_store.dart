import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/photo_store.dart';

/// 真实文件删除实现：照片与缩略图都在 App 私有目录的 `images/` 下。
class FilePhotoStore implements PhotoFileStore {
  Directory? _cached;

  Future<Directory> _imagesDir() async {
    final cached = _cached;
    if (cached != null) return cached;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/images');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return _cached = dir;
  }

  Future<void> deleteIfExists(String fileName) async {
    final dir = await _imagesDir();
    final file = File('${dir.path}/$fileName');
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> delete(String fileName) => deleteIfExists(fileName);
}
