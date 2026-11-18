import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/geo/place_catalog.dart';

/// 打开城市选择器：省 → 市两级，也支持直接搜索城市名。
///
/// 只返回地级市；省份仅作为导航层级（见 ADR-0003，省份不是数据维度）。
Future<Place?> showCityPicker(BuildContext context, {int? selectedCityId}) {
  return showModalBottomSheet<Place>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CityPickerSheet(selectedCityId: selectedCityId),
  );
}

class _CityPickerSheet extends ConsumerStatefulWidget {
  const _CityPickerSheet({this.selectedCityId});

  final int? selectedCityId;

  @override
  ConsumerState<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends ConsumerState<_CityPickerSheet> {
  final _searchController = TextEditingController();
  Place? _province;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(placeCatalogProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            _header(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: '搜索城市名',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: catalog.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('城市数据加载失败：$error')),
                data: (data) => _list(data, scrollController),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _header(BuildContext context) {
    final title = _province == null ? '选择省份' : _province!.name;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          if (_province != null)
            IconButton(
              tooltip: '返回省份',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _province = null),
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: Text(
              _query.isEmpty ? title : '搜索结果',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: '关闭',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _list(PlaceCatalog catalog, ScrollController controller) {
    if (_query.isNotEmpty) {
      final matches =
          catalog.cities.where((city) => city.name.contains(_query)).toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      if (matches.isEmpty) {
        return const Center(child: Text('没有找到匹配的城市'));
      }
      return ListView.builder(
        controller: controller,
        itemCount: matches.length,
        itemBuilder: (context, index) => _cityTile(matches[index], catalog),
      );
    }

    final province = _province;
    if (province == null) {
      final provinces = catalog.provinces.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return ListView.builder(
        controller: controller,
        itemCount: provinces.length,
        itemBuilder: (context, index) {
          final item = provinces[index];
          return ListTile(
            title: Text(item.name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => _province = item),
          );
        },
      );
    }

    final cities = catalog.citiesOf(province.id);
    if (cities.isEmpty) {
      return const Center(child: Text('该省份没有城市数据'));
    }
    return ListView.builder(
      controller: controller,
      itemCount: cities.length,
      itemBuilder: (context, index) => _cityTile(cities[index], catalog),
    );
  }

  Widget _cityTile(Place city, PlaceCatalog catalog) {
    final provinceName = _query.isEmpty
        ? null
        : catalog.byId(city.parentId)?.name;
    final selected = city.id == widget.selectedCityId;
    return ListTile(
      title: Text(city.name),
      subtitle: provinceName == null ? null : Text(provinceName),
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: () => Navigator.of(context).pop(city),
    );
  }
}
