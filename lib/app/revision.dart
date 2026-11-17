import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 任何写操作（新增/编辑/删除、导入）后自增，日历与地图据此刷新。
class MealsRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final mealsRevisionProvider = NotifierProvider<MealsRevision, int>(
  MealsRevision.new,
);
