import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/revision.dart';
import '../../data/geo/place_catalog.dart';
import '../../domain/models.dart';
import '../common/cuisine_colors.dart';
import '../meal/meal_detail_screen.dart';

const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

/// 美食日历：月视图（可点开当天）+ 年视图（只读热力图）。
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _month;
  bool _yearView = false;
  int _year = DateTime.now().year;
  late Future<List<Meal>> _future;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _month = DateTime(today.year, today.month);
    _future = _load();
  }

  Future<List<Meal>> _load() {
    if (_yearView) {
      return ref
          .read(mealRepositoryProvider)
          .mealsBetween(DateTime(_year, 1, 1), DateTime(_year, 12, 31));
    }
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    return ref
        .read(mealRepositoryProvider)
        .mealsBetween(_month, DateTime(_month.year, _month.month, days));
  }

  void _reload() => setState(() => _future = _load());

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _future = _load();
    });
  }

  void _toggleView() {
    setState(() {
      _yearView = !_yearView;
      _year = _month.year;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(mealsRevisionProvider, (_, _) => _reload());

    return Scaffold(
      appBar: AppBar(
        title: Text(_yearView ? '$_year 年' : '${_month.year}年${_month.month}月'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: _yearView ? '月视图' : '年视图',
            icon: Icon(_yearView ? Icons.calendar_view_month : Icons.grid_on),
            onPressed: _toggleView,
          ),
          if (_yearView)
            IconButton(
              tooltip: '上一年',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() {
                _year--;
                _future = _load();
              }),
            ),
          if (_yearView)
            IconButton(
              tooltip: '下一年',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() {
                _year++;
                _future = _load();
              }),
            ),
          if (!_yearView)
            IconButton(
              tooltip: '回到本月',
              icon: const Icon(Icons.today),
              onPressed: () {
                final today = DateTime.now();
                setState(() {
                  _month = DateTime(today.year, today.month);
                  _future = _load();
                });
              },
            ),
        ],
      ),
      body: FutureBuilder<List<Meal>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('读取日历失败：${snapshot.error}'));
          }
          final meals = snapshot.data;
          if (meals == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final byDay = <int, List<Meal>>{};
          for (final meal in meals) {
            final key = meal.eatenOn.year * 10000 +
                meal.eatenOn.month * 100 +
                meal.eatenOn.day;
            byDay.putIfAbsent(key, () => []).add(meal);
          }
          return _yearView ? _yearHeatmap(byDay) : _monthView(byDay);
        },
      ),
    );
  }

  // ------------------------------------------------------------------ 月视图

  Widget _monthView(Map<int, List<Meal>> byDay) {
    final firstDay = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // 周一为第一列：weekday 1=Mon … 7=Sun
    final leading = firstDay.weekday - 1;
    final today = DateTime.now();
    final cells = <DateTime?>[
      for (var i = 0; i < leading; i++) null,
      for (var day = 1; day <= daysInMonth; day++)
        DateTime(_month.year, _month.month, day),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Column(
      children: [
        Row(
          children: [
            for (final name in _weekdays)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 64,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: cells.length,
          itemBuilder: (context, index) {
            final date = cells[index];
            if (date == null) return const SizedBox.shrink();
            final key = date.year * 10000 + date.month * 100 + date.day;
            return _dayCell(
              date,
              byDay[key] ?? const [],
              isToday: date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day,
            );
          },
        ),
        const SizedBox(height: 8),
        _monthSummary(byDay),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              IconButton(
                tooltip: '上个月',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shiftMonth(-1),
              ),
              const Spacer(),
              Text(
                '共 ${byDay.values.fold<int>(0, (sum, list) => sum + list.length)} 餐',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              IconButton(
                tooltip: '下个月',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shiftMonth(1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _monthSummary(Map<int, List<Meal>> byDay) {
    final meals = byDay.values.expand((list) => list).toList();
    if (meals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          '这个月还没有记录',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    final cities = meals.map((m) => m.cityCode).toSet().length;
    final cuisineCounts = <String, int>{};
    for (final meal in meals) {
      cuisineCounts[meal.cuisineId] = (cuisineCounts[meal.cuisineId] ?? 0) + 1;
    }
    final top = cuisineCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '本月 ${meals.length} 餐 · ${byDay.length} 天 · $cities 个城市',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          for (final entry in top.take(4))
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: cuisineColor(entry.key),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${_cuisineName(entry.key)} ${entry.value}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _cuisineName(String id) {
    final cuisines = ref.watch(cuisinesProvider).value ?? const <Cuisine>[];
    final matches = cuisines.where((c) => c.id == id);
    return matches.isEmpty ? id : matches.first.name;
  }

  Widget _dayCell(DateTime date, List<Meal> meals, {required bool isToday}) {
    final scheme = Theme.of(context).colorScheme;
    final dishes = meals.isEmpty ? null : meals.first.dishes;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: meals.isEmpty ? null : () => _openDay(date, meals),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isToday ? scheme.primaryContainer.withValues(alpha: 0.55) : null,
          border: isToday ? Border.all(color: scheme.primary, width: 1.2) : null,
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${date.day}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: isToday ? FontWeight.w700 : null,
                  ),
            ),
            const Spacer(),
            Wrap(
              spacing: 3,
              runSpacing: 2,
              children: [
                for (final meal in meals.take(4))
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: cuisineColor(meal.cuisineId),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            if (meals.isNotEmpty && dishes != null)
              Text(
                meals.length == 1
                    ? (dishes.isEmpty ? '' : dishes.first.name)
                    : '${meals.length} 餐',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDay(DateTime date, List<Meal> meals) async {
    var changed = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (context, controller) => _DaySheet(
          date: date,
          meals: meals,
          scrollController: controller,
          onChanged: () => changed = true,
        ),
      ),
    );
    if (changed) _reload();
  }

  // ------------------------------------------------------------------ 年视图

  Widget _yearHeatmap(Map<int, List<Meal>> byDay) {
    final scheme = Theme.of(context).colorScheme;
    final maxCount = byDay.values
        .fold<int>(0, (max, list) => list.length > max ? list.length : max);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: [
        for (var month = 1; month <= 12; month++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '$month 月',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                for (var day = 1; day <= 31; day++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _heatCell(
                          byDay[month * 100 + day]?.length ?? 0,
                          maxCount,
                          scheme,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('少', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 6),
            for (final count in [0, 1, 2, 3, 5])
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: _heatCell(count, 5, scheme),
                ),
              ),
            const SizedBox(width: 6),
            Text('多（最多 $maxCount 餐/天）',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }

  Widget _heatCell(int count, int maxCount, ColorScheme scheme) {
    if (count == 0) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    final ratio = maxCount <= 1 ? 1.0 : (count / maxCount).clamp(0.0, 1.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(
          scheme.primary.withValues(alpha: 0.35),
          scheme.primary,
          ratio,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _DaySheet extends ConsumerWidget {
  const _DaySheet({
    required this.date,
    required this.meals,
    required this.scrollController,
    required this.onChanged,
  });

  final DateTime date;
  final List<Meal> meals;
  final ScrollController scrollController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(placeCatalogProvider).value;
    final cuisines = ref.watch(cuisinesProvider).value ?? const <Cuisine>[];
    String cuisineName(String id) {
      final matches = cuisines.where((c) => c.id == id);
      return matches.isEmpty ? '未知菜系' : matches.first.name;
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          '${date.month}月${date.day}日 · ${meals.length} 餐',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final meal in meals)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                radius: 6,
                backgroundColor: cuisineColor(meal.cuisineId),
              ),
              title: Text(cuisineName(meal.cuisineId)),
              subtitle: Text(_subtitle(meal, catalog)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => MealDetailScreen(meal: meal),
                  ),
                );
                if (result == true) onChanged();
              },
            ),
          ),
      ],
    );
  }

  String _subtitle(Meal meal, PlaceCatalog? catalog) {
    final city = catalog?.byId(int.tryParse(meal.cityCode) ?? -1)?.name;
    final parts = <String>[
      ?city,
      if (meal.dishes.isNotEmpty) meal.dishes.map((d) => d.name).join('、'),
      if (meal.tags.isNotEmpty) meal.tags.map((t) => '#${t.name}').join(' '),
    ];
    return parts.join(' · ');
  }
}
