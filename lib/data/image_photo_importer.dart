import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import '../domain/photo_importer.dart';
import '../domain/photo_store.dart';

/// 原图长边上限，见 spec §5。
const int kPhotoMaxEdge = 2048;
const int kPhotoQuality = 80;
const int kThumbEdge = 200;
const int kThumbQuality = 70;

class ImagePhotoImporter implements PhotoImporter {
  ImagePhotoImporter(this._store, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final PhotoFileStore _store;
  final Uuid _uuid;

  @override
  Future<PhotoDraft> importFrom(String sourcePath, {required int position}) async {
    final dirPath = await _store.imagesDirPath();
    final id = _uuid.v4();
    final fileName = '$id.jpg';
    final thumbName = 't_$id.jpg';

    final source = File(sourcePath);
    final bytes = await source.readAsBytes();
    final decoded = await decodeImageFromList(bytes);
    final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
    final scale = longest > kPhotoMaxEdge ? kPhotoMaxEdge / longest : 1.0;
    final targetWidth = (decoded.width * scale).round();
    final targetHeight = (decoded.height * scale).round();
    decoded.dispose();

    final compressed = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      '$dirPath/$fileName',
      format: CompressFormat.jpeg,
      quality: kPhotoQuality,
      minWidth: targetWidth,
      minHeight: targetHeight,
    );
    if (compressed == null) {
      throw const FileSystemException('照片压缩失败');
    }

    await FlutterImageCompress.compressAndGetFile(
      compressed.path,
      '$dirPath/$thumbName',
      format: CompressFormat.jpeg,
      quality: kThumbQuality,
      minWidth: kThumbEdge,
      minHeight: kThumbEdge,
    );

    return PhotoDraft(
      fileName: fileName,
      thumbName: thumbName,
      width: targetWidth,
      height: targetHeight,
      position: position,
    );
  }
}
