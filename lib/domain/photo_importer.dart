import 'models.dart';

/// 把用户相册里的原图变成 App 私有目录里的「压缩图 + 缩略图」。
///
/// 抽成接口是为了让表单测试不需要真的解码图片（见 ADR-0002）。
abstract class PhotoImporter {
  /// [sourcePath] 可以是相册返回的临时文件；实现负责压缩、生成缩略图、
  /// 落盘到私有目录，并返回可用于 [MealDraft.photos] 的草稿。
  Future<PhotoDraft> importFrom(String sourcePath, {required int position});
}
