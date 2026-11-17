import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/revision.dart';
import '../../domain/models.dart';
import '../common/cuisine_colors.dart';
import '../meal/meal_form_screen.dart';

const _slotLabels = {
  MealSlot.breakfast: '早餐',
  MealSlot.lunch: '午餐',
  MealSlot.dinner: '晚餐',
  MealSlot.snack: '加餐',
};

/// 一餐的详情页：只读展示，底部提供编辑与删除。
class MealDetailScreen extends ConsumerWidget {
  const MealDetailScreen({super.key, required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(placeCatalogProvider).value;
    final cuisines = ref.watch(cuisinesProvider).value ?? const <Cuisine>[];
    final matches = cuisines.where((c) => c.id == meal.cuisineId);
    final cuisineName = matches.isEmpty ? null : matches.first.name;
    final cityName = catalog?.byId(int.tryParse(meal.cityCode) ?? -1)?.name;

    return Scaffold(
      appBar: AppBar(title: const Text('这一餐')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (meal.photos.isNotEmpty) _photoStrip(ref),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: cuisineColor(meal.cuisineId),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      cuisineName ?? '未知菜系',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    Text(
                      '${meal.eatenOn.year}年${meal.eatenOn.month}月${meal.eatenOn.day}日',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (meal.slot != null) _slotLabels[meal.slot],
                    cityName ?? '未知城市',
                  ].whereType<String>().join(' · '),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (meal.dishes.isNotEmpty) ...[
            _sectionTitle(context, '吃了什么'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final dish in meal.dishes)
                    Chip(label: Text(dish.name)),
                ],
              ),
            ),
          ],
          if (meal.tags.isNotEmpty) ...[
            _sectionTitle(context, '标签'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in meal.tags)
                    Chip(
                      label: Text('#${tag.name}'),
                      backgroundColor:
                          Theme.of(context).colorScheme.secondaryContainer,
                    ),
                ],
              ),
            ),
          ],
          if ((meal.note ?? '').isNotEmpty) ...[
            _sectionTitle(context, '备注'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(meal.note!),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('编辑'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _delete(context, ref),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      );

  Widget _photoStrip(WidgetRef ref) {
    final store = ref.read(photoStoreProvider);
    return SizedBox(
      height: 240,
      child: PageView(
        children: [
          for (final photo in meal.photos)
            FutureBuilder<String>(
              future: store.pathOf(photo.fileName),
              builder: (context, snapshot) {
                final path = snapshot.data;
                if (path == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  cacheWidth: 1080,
                  errorBuilder: (context, error, stack) => const Center(
                    child: Icon(Icons.broken_image_outlined, size: 40),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MealFormScreen(meal: meal)),
    );
    if (saved == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这一餐？'),
        content: const Text('照片也会一起删除，无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(mealRepositoryProvider).deleteMeal(meal.id);
    ref.read(mealsRevisionProvider.notifier).bump();
    if (context.mounted) Navigator.of(context).pop(true);
  }
}
