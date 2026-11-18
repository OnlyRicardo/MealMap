import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/revision.dart';
import '../../domain/meal_repository.dart';
import '../../domain/models.dart';
import '../../domain/rules.dart';
import '../common/cuisine_colors.dart';

/// 设置：菜系与标签的管理，以及关于页。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuisines = ref.watch(allCuisinesProvider);
    final tags = ref.watch(tagsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _sectionHeader(
            context,
            '菜系',
            action: TextButton.icon(
              onPressed: () => _addCuisine(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新增'),
            ),
          ),
          cuisines.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => ListTile(title: Text('读取失败：$error')),
            data: (items) => Column(
              children: [
                for (final cuisine in items)
                  ListTile(
                    leading: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: cuisineColor(cuisine.id),
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(cuisine.name),
                    subtitle: Text(_cuisineSubtitle(cuisine)),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) =>
                          _cuisineAction(context, ref, cuisine, value),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'rename', child: Text('改名')),
                        if (cuisine.isArchived)
                          const PopupMenuItem(
                            value: 'restore',
                            child: Text('恢复'),
                          )
                        else
                          const PopupMenuItem(
                            value: 'archive',
                            child: Text('归档'),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 32),
          _sectionHeader(context, '标签'),
          tags.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => ListTile(title: Text('读取失败：$error')),
            data: (items) => items.isEmpty
                ? const ListTile(title: Text('还没有标签'))
                : Column(
                    children: [
                      for (final tag in items)
                        ListTile(
                          title: Text('#${tag.name}'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) =>
                                _tagAction(context, ref, tag, value, items),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'rename',
                                child: Text('重命名'),
                              ),
                              const PopupMenuItem(
                                value: 'merge',
                                child: Text('合并到…'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('删除'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          const Divider(height: 32),
          _sectionHeader(context, '数据'),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('导出备份（含照片）'),
            subtitle: const Text('生成 zip 后通过系统分享发送；换机时在新手机上导入'),
            onTap: () => _export(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('导入备份'),
            subtitle: const Text('与现有数据合并，重复的记录会跳过'),
            onTap: () => _import(context, ref),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于 MealMap'),
            subtitle: const Text('本地优先的饮食日志 · v1'),
            onTap: () => _about(context),
          ),
        ],
      ),
    );
  }

  String _cuisineSubtitle(Cuisine cuisine) {
    final labels = [if (cuisine.isBuiltin) '内置', if (cuisine.isArchived) '已归档'];
    return labels.isEmpty ? '自定义' : labels.join(' · ');
  }

  Widget _sectionHeader(BuildContext context, String title, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          ?action,
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ 菜系

  Future<void> _addCuisine(BuildContext context, WidgetRef ref) async {
    final name = await _askText(context, title: '新增菜系', hint: '例如：湘菜');
    if (name == null) return;
    try {
      await ref.read(mealRepositoryProvider).addCuisine(name);
      _refreshCuisines(ref);
    } on MealMapException catch (error) {
      if (context.mounted) _snack(context, error.message);
    }
  }

  Future<void> _cuisineAction(
    BuildContext context,
    WidgetRef ref,
    Cuisine cuisine,
    String action,
  ) async {
    final repo = ref.read(mealRepositoryProvider);
    switch (action) {
      case 'rename':
        final name = await _askText(
          context,
          title: '重命名菜系',
          hint: cuisine.name,
          initial: cuisine.name,
        );
        if (name == null) return;
        try {
          await repo.renameCuisine(cuisine.id, name);
          _refreshCuisines(ref);
        } on MealMapException catch (error) {
          if (context.mounted) _snack(context, error.message);
        }
      case 'archive':
        await repo.archiveCuisine(cuisine.id);
        _refreshCuisines(ref);
      case 'restore':
        await repo.restoreCuisine(cuisine.id);
        _refreshCuisines(ref);
    }
  }

  void _refreshCuisines(WidgetRef ref) {
    ref.invalidate(allCuisinesProvider);
    ref.invalidate(cuisinesProvider);
    ref.read(mealsRevisionProvider.notifier).bump();
  }

  // ------------------------------------------------------------------ 标签

  Future<void> _tagAction(
    BuildContext context,
    WidgetRef ref,
    Tag tag,
    String action,
    List<Tag> all,
  ) async {
    final repo = ref.read(mealRepositoryProvider);
    switch (action) {
      case 'rename':
        final name = await _askText(
          context,
          title: '重命名标签',
          hint: tag.name,
          initial: tag.name,
          validator: _validateTag,
        );
        if (name == null) return;
        try {
          await repo.renameTag(tag.id, name);
          _refreshTags(ref);
        } on MealMapException catch (error) {
          if (context.mounted) _snack(context, error.message);
        }
      case 'merge':
        final others = all.where((t) => t.id != tag.id).toList();
        if (others.isEmpty) {
          _snack(context, '没有可以合并的目标标签');
          return;
        }
        final target = await showDialog<Tag>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text('把「${tag.name}」合并到'),
            children: [
              for (final other in others)
                SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(other),
                  child: Text('#${other.name}'),
                ),
            ],
          ),
        );
        if (target == null) return;
        await repo.mergeTags(tag.id, target.id);
        _refreshTags(ref);
        ref.read(mealsRevisionProvider.notifier).bump();
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('删除标签「${tag.name}」？'),
            content: const Text('只解除标签与记录的关系，记录本身不会删除。'),
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
        if (confirmed != true) return;
        await repo.deleteTag(tag.id);
        _refreshTags(ref);
        ref.read(mealsRevisionProvider.notifier).bump();
    }
  }

  void _refreshTags(WidgetRef ref) {
    ref.invalidate(tagsProvider);
  }

  String? _validateTag(String value) {
    final trimmed = value.trim();
    if (trimmed.length < kMinTagLength || trimmed.length > kMaxTagLength) {
      return '需要 $kMinTagLength–$kMaxTagLength 个字';
    }
    return null;
  }

  Future<String?> _askText(
    BuildContext context, {
    required String title,
    required String hint,
    String? initial,
    String? Function(String)? validator,
  }) {
    final controller = TextEditingController(text: initial);
    String? error = validator?.call(initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: hint, errorText: error),
            onChanged: (value) =>
                setState(() => error = validator?.call(value)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: error != null
                  ? null
                  : () {
                      final text = controller.text.trim();
                      if (text.isEmpty) {
                        setState(() => error = '不能为空');
                        return;
                      }
                      Navigator.of(context).pop(text);
                    },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('正在打包备份…')));
    try {
      await ref.read(backupServiceProvider).exportAndShare();
    } catch (error) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('导出失败：$error')));
      }
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = picked.isEmpty ? null : picked.single.path;
    if (path == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入备份？'),
        content: const Text('备份中的记录会合并到现有数据；ID 重复的记录会跳过，不会覆盖。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final summary = await ref.read(backupServiceProvider).importArchive(path);
      ref.invalidate(cuisinesProvider);
      ref.invalidate(allCuisinesProvider);
      ref.invalidate(tagsProvider);
      ref.read(mealsRevisionProvider.notifier).bump();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '导入完成：新增 ${summary.imported} 餐，跳过 ${summary.skipped} 餐',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('导入失败：$error')));
    }
  }

  void _about(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'MealMap',
      applicationVersion: '1.0.0 (v1)',
      applicationLegalese:
          'MIT License · 数据完全保存在本机\n'
          '地图为城市点阵示意，不包含行政区域界线。',
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
