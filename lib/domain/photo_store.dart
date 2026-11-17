/// 照片文件的删除入口。
///
/// 数据层只负责决定"哪些文件该删"，真正碰文件系统的事情交给实现，
/// 这样单元测试可以用假实现，也不需要 Flutter 运行时。
abstract class PhotoFileStore {
  Future<void> delete(String fileName);
}
