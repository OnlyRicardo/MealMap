/// 照片文件的位置与删除入口。
///
/// 数据层只负责决定"哪些文件该删"，真正碰文件系统的事情交给实现，
/// 这样单元测试可以用假实现，也不需要 Flutter 运行时。
abstract class PhotoFileStore {
  Future<void> delete(String fileName);

  /// 给 UI 用的绝对路径：私有目录里的照片/缩略图文件名 → 完整路径。
  Future<String> pathOf(String fileName);

  /// 照片私有目录的绝对路径；导入器把文件写到这里。
  Future<String> imagesDirPath();
}
