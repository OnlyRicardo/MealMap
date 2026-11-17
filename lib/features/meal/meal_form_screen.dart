import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/meal_repository.dart';
import '../../domain/models.dart';
import '../../domain/rules.dart';
import 'city_picker.dart';

const _slotLabels = {
  MealSlot.breakfast: '早餐',
  MealSlot.lunch: '午餐',
  MealSlot.dinner: '晚餐',
  MealSlot.snack: '加餐',
};

String formatDay(DateTime date) =>
    '${date.year}年${date.month}月${date.day}日';

String _weekdayLabel(DateTime date) {
  const names = ['一', '二', '三', '四', '五', '六', '日'];
  return '周${names[date.weekday - 1]}';
}

/// 记一餐 / 编辑一餐。照片在 T5 接入。
class MealFormScreen extends ConsumerStatefulWidget {
  const MealFormScreen({super.key, this.meal});

  final Meal? meal;

  @override
  ConsumerState<MealFormScreen> createState() => _MealFormScreenState();
}

class _MealFormScreenState extends ConsumerState<MealFormScreen> {
  late DateTime _date;
  MealSlot? _slot;
  int? _cityId;
  String? _cuisineId;
  late List<String> _dishes;
  late List<String> _tags;
  late final TextEditingController _noteController;
  late final TextEditingController _dishController;
  late final TextEditingController _tagController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final meal = widget.meal;
    final now = DateTime.now();
    _date = meal?.eatenOn ?? dateOnly(now);
    _slot = meal?.slot;
    _cityId = int.tryParse(meal?.cityCode ?? '');
    _cuisineId = meal?.cuisineId;
    _dishes = meal?.dishes.map((d) => d.name).toList() ?? [];
    _tags = meal?.tags.map((t) => t.name).toList() ?? [];
    _noteController = TextEditingController(text: meal?.note ?? '');
    _dishController = TextEditingController();
    _tagController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _dishController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(placeCatalogProvider).value;
    final cityName = _cityId == null ? null : catalog?.byId(_cityId!)?.name;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.meal == null ? '记一餐' : '编辑这一餐'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _section('日期'),
          _dateRow(),
          const SizedBox(height: 20),
          _section('餐次（可不填）'),
          _slotChips(),
          const SizedBox(height: 20),
          _section('在哪里'),
          _cityTile(cityName),
          const SizedBox(height: 20),
          _section('菜系'),
          _cuisineChips(),
          const SizedBox(height: 20),
          _section('吃了什么'),
          _dishesSection(),
          const SizedBox(height: 20),
          _section('标签'),
          _tagsSection(),
          const SizedBox(height: 20),
          _section('备注'),
          TextField(
            controller: _noteController,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: '和谁一起、味道如何……',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_saving ? '保存中…' : '保存'),
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      );

  Widget _dateRow() {
    final today = dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today, size: 18),
          label: Text('${formatDay(_date)} ${_weekdayLabel(_date)}'),
        ),
        ChoiceChip(
          label: const Text('今天'),
          selected: _sameDay(_date, today),
          onSelected: (_) => setState(() => _date = today),
        ),
        ChoiceChip(
          label: const Text('昨天'),
          selected: _sameDay(_date, yesterday),
          onSelected: (_) => setState(() => _date = yesterday),
        ),
      ],
    );
  }

  Widget _slotChips() {
    return Wrap(
      spacing: 8,
      children: [
        for (final entry in _slotLabels.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: _slot == entry.key,
            onSelected: (selected) => setState(
              () => _slot = selected ? entry.key : null,
            ),
          ),
      ],
    );
  }

  Widget _cityTile(String? cityName) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.place_outlined),
        title: Text(cityName ?? '选择城市'),
        subtitle: cityName == null ? const Text('记录在哪里吃的') : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final picked = await showCityPicker(context, selectedCityId: _cityId);
          if (picked != null) {
            setState(() => _cityId = picked.id);
          }
        },
      ),
    );
  }

  Widget _cuisineChips() {
    final cuisines = ref.watch(cuisinesProvider);
    return cuisines.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      ),
      error: (error, _) => Text('菜系加载失败：$error'),
      data: (items) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final cuisine in items)
            ChoiceChip(
              label: Text(cuisine.name),
              selected: _cuisineId == cuisine.id,
              onSelected: (selected) => setState(
                () => _cuisineId = selected ? cuisine.id : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _dishesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_dishes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _dishes.length; i++)
                  InputChip(
                    label: Text(_dishes[i]),
                    onDeleted: () => setState(() => _dishes.removeAt(i)),
                  ),
              ],
            ),
          ),
        TextField(
          controller: _dishController,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: '输入菜名，回车添加',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _addDish(),
        ),
      ],
    );
  }

  Widget _tagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _tags.length; i++)
                  InputChip(
                    label: Text(_tags[i]),
                    onDeleted: () => setState(() => _tags.removeAt(i)),
                  ),
              ],
            ),
          ),
        TextField(
          controller: _tagController,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: '$kMinTagLength–$kMaxTagLength 个字，回车添加',
            helperText: '已添加 ${_tags.length}/$kMaxTagsPerMeal',
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _addTag(),
        ),
      ],
    );
  }

  void _addDish() {
    final name = _dishController.text.trim();
    if (name.isEmpty) return;
    if (_dishes.length >= kMaxDishesPerMeal) {
      _snack('一道菜最多 $kMaxDishesPerMeal 行');
      return;
    }
    if (_dishes.contains(name)) {
      _snack('「$name」已经加过了');
      return;
    }
    setState(() {
      _dishes.add(name);
      _dishController.clear();
    });
  }

  void _addTag() {
    final name = _tagController.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) return;
    if (name.length < kMinTagLength || name.length > kMaxTagLength) {
      _snack('标签需要 $kMinTagLength–$kMaxTagLength 个字');
      return;
    }
    if (_tags.any((tag) => tag.toLowerCase() == name.toLowerCase())) {
      _snack('标签「$name」已经加过了');
      return;
    }
    if (_tags.length >= kMaxTagsPerMeal) {
      _snack('一餐最多 $kMaxTagsPerMeal 个标签');
      return;
    }
    setState(() {
      _tags.add(name);
      _tagController.clear();
    });
  }

  Future<void> _pickDate() async {
    final now = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _date = dateOnly(picked));
    }
  }

  Future<void> _save() async {
    if (_cityId == null) {
      _snack('请选择城市');
      return;
    }
    if (_cuisineId == null) {
      _snack('请选择菜系');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(mealRepositoryProvider).saveMeal(
            MealDraft(
              id: widget.meal?.id,
              eatenOn: _date,
              slot: _slot,
              cityCode: _cityId.toString(),
              cuisineId: _cuisineId!,
              note: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
              dishes: _dishes,
              tagNames: _tags,
            ),
          );
      ref.invalidate(cuisinesProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on MealMapException catch (error) {
      _snack(error.message);
    } catch (error) {
      _snack('保存失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
