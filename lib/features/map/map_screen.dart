import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/meal_repository.dart';

/// 美食地图（首页）。
///
/// T6 才会绘制真实地图；此刻只验证数据链路与应用外壳能跑起来。
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late Future<List<CityCount>> _counts;

  @override
  void initState() {
    super.initState();
    _counts = ref.read(mealRepositoryProvider).cityCounts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('美食地图')),
      body: Center(
        child: FutureBuilder<List<CityCount>>(
          future: _counts,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('读取数据失败：${snapshot.error}');
            }
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }
            final cities = snapshot.data!;
            if (cities.isEmpty) {
              return const _EmptyState();
            }
            return Text('已记录 ${cities.length} 个城市');
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('记一餐：T4 实现')),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('记一餐'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.ramen_dining,
          size: 64,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 12),
        Text(
          '还没有记录\n点右下角记下第一餐',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}
