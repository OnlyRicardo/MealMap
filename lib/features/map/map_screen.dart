import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/geo/place_catalog.dart';
import '../meal/meal_form_screen.dart';
import 'city_dot_map.dart';

class _MapData {
  const _MapData({required this.counts, required this.years, required this.total});

  final Map<int, int> counts;
  final List<int> years;
  final int total;
}

/// 美食地图（首页）：城市点阵 + 年份切换。
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  /// null 表示全部年份。
  int? _year;
  late Future<_MapData> _future;
  Place? _selected;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_MapData> _load() async {
    final repo = ref.read(mealRepositoryProvider);
    final counts = await repo.cityCounts(year: _year);
    final years = await repo.yearsWithMeals();
    final map = <int, int>{};
    var total = 0;
    for (final count in counts) {
      final id = int.tryParse(count.cityCode);
      if (id == null) continue;
      map[id] = (map[id] ?? 0) + count.count;
      total += count.count;
    }
    return _MapData(counts: map, years: years, total: total);
  }

  void _refresh() {
    setState(() {
      _selected = null;
      _future = _load();
    });
  }

  void _setYear(int? year) {
    setState(() {
      _year = year;
      _selected = null;
      _future = _load();
    });
  }

  Future<void> _openForm() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const MealFormScreen()),
    );
    if (saved == true && mounted) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(placeCatalogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('美食地图'),
        actions: [_yearMenu()],
      ),
      body: FutureBuilder<_MapData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('读取数据失败：${snapshot.error}'));
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return catalog.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('地图数据加载失败：$error')),
            data: (places) => _body(places, data),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('记一餐'),
      ),
    );
  }

  Widget _yearMenu() {
    return FutureBuilder<_MapData>(
      future: _future,
      builder: (context, snapshot) {
        final years = snapshot.data?.years ?? const <int>[];
        return PopupMenuButton<int?>(
          tooltip: '切换年份',
          initialValue: _year,
          onSelected: _setYear,
          itemBuilder: (context) => [
            CheckedPopupMenuItem<int?>(
              value: null,
              checked: _year == null,
              child: const Text('全部年份'),
            ),
            for (final year in years)
              CheckedPopupMenuItem<int?>(
                value: year,
                checked: _year == year,
                child: Text('$year 年'),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(_year == null ? '全部年份' : '$_year 年'),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _body(PlaceCatalog places, _MapData data) {
    final selected = _selected;
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: CityDotMap(
                  catalog: places,
                  counts: data.counts,
                  onCityTap: (city) => setState(() => _selected = city),
                ),
              ),
              if (data.total == 0)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 32,
                  child: IgnorePointer(
                    child: Text(
                      '还没有记录\n点右下角记下第一餐',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
        _legend(data),
        if (selected != null) _cityCard(selected, data),
      ],
    );
  }

  Widget _legend(_MapData data) {
    if (data.total == 0) return const SizedBox(height: 8);
    final maxCount =
        data.counts.values.fold<int>(0, (a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '已记录 ${data.total} 餐',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          const Text('少', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          _LegendDot(ratio: 0.2),
          const SizedBox(width: 4),
          _LegendDot(ratio: 0.6),
          const SizedBox(width: 4),
          _LegendDot(ratio: 1),
          const SizedBox(width: 6),
          Text('$maxCount 餐', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _cityCard(Place city, _MapData data) {
    final count = data.counts[city.id] ?? 0;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ListTile(
        leading: const Icon(Icons.place),
        title: Text(city.name),
        subtitle: Text(count == 0 ? '还没在这里吃过' : '吃了 $count 餐'),
        trailing: IconButton(
          tooltip: '关闭',
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _selected = null),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 6 + 10 * ratio,
      height: 6 + 10 * ratio,
      decoration: BoxDecoration(
        color: Color.lerp(
          scheme.primary.withValues(alpha: 0.7),
          scheme.primary,
          ratio,
        ),
        shape: BoxShape.circle,
      ),
    );
  }
}
