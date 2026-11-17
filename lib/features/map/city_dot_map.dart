import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../data/geo/place_catalog.dart';

/// 墨卡托投影 + 等比缩放，把经纬度映射到画布坐标。
///
/// 只做点投影，不生成任何边界线（见 ADR-0003）。
class MapProjection {
  MapProjection(PlaceCatalog catalog) {
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final place in catalog.all) {
      final x = place.lng * math.pi / 180;
      final y = -_mercatorY(place.lat);
      _projected[place.id] = Offset(x, y);
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
    _minX = minX;
    _maxX = maxX;
    _minY = minY;
    _maxY = maxY;
  }

  final Map<int, Offset> _projected = {};
  late final double _minX;
  late final double _maxX;
  late final double _minY;
  late final double _maxY;

  static double _mercatorY(double latitude) {
    final clamped = latitude.clamp(-85.0, 85.0);
    return math.log(math.tan(math.pi / 4 + clamped * math.pi / 360));
  }

  Offset of(Place place) => _projected[place.id] ?? Offset.zero;

  /// 等比适配到 [size] 内，四周留 [padding]。
  ProjectionTransform fit(Size size, EdgeInsets padding) {
    final width = _maxX - _minX;
    final height = _maxY - _minY;
    final scale = math.min(
      (size.width - padding.horizontal) / width,
      (size.height - padding.vertical) / height,
    );
    final dx = padding.left + (size.width - padding.horizontal - width * scale) / 2;
    final dy = padding.top + (size.height - padding.vertical - height * scale) / 2;
    return ProjectionTransform(
      scale: scale,
      origin: Offset(dx - _minX * scale, dy - _minY * scale),
    );
  }
}

/// 画布坐标变换：`projected * scale + origin`。
class ProjectionTransform {
  const ProjectionTransform({required this.scale, required this.origin});

  final double scale;
  final Offset origin;

  Offset call(Offset projected) => projected * scale + origin;
}

/// 点阵美食地图。
///
/// - 区县点：静态背景，勾勒轮廓，不可点。
/// - 城市点：按 Meal 数量放大、加深；可点击。
class CityDotMap extends StatefulWidget {
  const CityDotMap({
    super.key,
    required this.catalog,
    required this.counts,
    this.onCityTap,
  });

  final PlaceCatalog catalog;

  /// 城市 id → 餐数。没有记录的城市的不会出现。
  final Map<int, int> counts;
  final ValueChanged<Place>? onCityTap;

  @override
  State<CityDotMap> createState() => _CityDotMapState();
}

class _CityDotMapState extends State<CityDotMap> {
  MapProjection? _projection;
  List<Place>? _districts;
  List<Place>? _cities;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(CityDotMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catalog != widget.catalog) _prepare();
  }

  void _prepare() {
    _projection = MapProjection(widget.catalog);
    _districts = widget.catalog.districts.toList(growable: false);
    _cities = widget.catalog.cities.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final projection = _projection;
    final districts = _districts;
    final cities = _cities;
    if (projection == null || districts == null || cities == null) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final transform = projection.fit(size, const EdgeInsets.all(12));
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _handleTap(projection, transform, details.localPosition),
          child: CustomPaint(
            size: size,
            painter: _DotMapPainter(
              projection: projection,
              transform: transform,
              districts: districts,
              cities: cities,
              counts: widget.counts,
              scheme: scheme,
            ),
          ),
        );
      },
    );
  }

  void _handleTap(MapProjection projection, ProjectionTransform transform, Offset position) {
    Place? nearest;
    var nearestDistance = 28.0;
    for (final city in _cities!) {
      final offset = transform(projection.of(city));
      final distance = (offset - position).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = city;
      }
    }
    if (nearest != null) widget.onCityTap?.call(nearest);
  }
}

class _DotMapPainter extends CustomPainter {
  _DotMapPainter({
    required this.projection,
    required this.transform,
    required this.districts,
    required this.cities,
    required this.counts,
    required this.scheme,
  });

  final MapProjection projection;
  final ProjectionTransform transform;
  final List<Place> districts;
  final List<Place> cities;
  final Map<int, int> counts;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final maxCount = counts.values.isEmpty
        ? 1
        : counts.values.reduce((a, b) => a > b ? a : b);

    // 背景：区县点，只用来勾勒形状，颜色刻意压得很淡。
    final background = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    for (final district in districts) {
      canvas.drawCircle(transform(projection.of(district)), 1.9, background);
    }

    // 城市点：没吃过的用轮廓色，吃过按数量放大加深。
    final visited = <int, int>{};
    final unvisited = Paint()
      ..color = scheme.outline.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    for (final city in cities) {
      final offset = transform(projection.of(city));
      final count = counts[city.id] ?? 0;
      if (count <= 0) {
        canvas.drawCircle(offset, 2.6, unvisited);
        continue;
      }
      visited[city.id] = count;
      final ratio = maxCount <= 1 ? 1.0 : (count / maxCount).clamp(0.0, 1.0);
      final radius = 4.0 + 7.0 * math.sqrt(ratio);
      final color = Color.lerp(scheme.primary.withValues(alpha: 0.75), scheme.primary, ratio)!;
      canvas.drawCircle(
        offset,
        radius + 2.5,
        Paint()..color = color.withValues(alpha: 0.18),
      );
      canvas.drawCircle(offset, radius, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_DotMapPainter oldDelegate) {
    if (oldDelegate.transform.scale != transform.scale ||
        oldDelegate.transform.origin != transform.origin ||
        oldDelegate.projection != projection ||
        oldDelegate.scheme != scheme) {
      return true;
    }
    if (oldDelegate.counts.length != counts.length) return true;
    for (final entry in counts.entries) {
      if (oldDelegate.counts[entry.key] != entry.value) return true;
    }
    return false;
  }
}
