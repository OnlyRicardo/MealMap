/// 行政区点位目录。
///
/// 刻意只包含「点」：名称、隶属关系与中心坐标，**不包含任何边界线**。
/// 这样地图是示意性点阵，而不是需要审图号的行政区地图（见 ADR-0003）。
library;

class Place {
  const Place({
    required this.id,
    required this.parentId,
    required this.level,
    required this.name,
    required this.lng,
    required this.lat,
  });

  /// AreaCity 的短码（行政区划代码去掉尾部 0），仅在本项目内部使用。
  final int id;
  final int parentId;

  /// 0 = 省级，1 = 地级市，2 = 区县。
  final int level;
  final String name;
  final double lng;
  final double lat;

  bool get isProvince => level == 0;
  bool get isCity => level == 1;
  bool get isDistrict => level == 2;
}

class PlaceCatalog {
  PlaceCatalog._(this._byId, this._byParent);

  factory PlaceCatalog.fromJson(Map<String, dynamic> json) {
    final places = <Place>[];
    final raw = json['places'];
    if (raw is! List) {
      throw const FormatException('places.json 缺少 places 数组');
    }
    for (final item in raw) {
      if (item is! List || item.length < 6) continue;
      places.add(Place(
        id: item[0] as int,
        parentId: item[1] as int,
        level: item[2] as int,
        name: item[3] as String,
        lng: (item[4] as num).toDouble(),
        lat: (item[5] as num).toDouble(),
      ));
    }
    final byId = {for (final p in places) p.id: p};
    final byParent = <int, List<Place>>{};
    for (final p in places) {
      byParent.putIfAbsent(p.parentId, () => []).add(p);
    }
    for (final list in byParent.values) {
      list.sort((a, b) => a.id.compareTo(b.id));
    }
    return PlaceCatalog._(byId, byParent);
  }

  final Map<int, Place> _byId;
  final Map<int, List<Place>> _byParent;

  Iterable<Place> get all => _byId.values;
  Iterable<Place> get provinces => all.where((p) => p.isProvince);
  Iterable<Place> get cities => all.where((p) => p.isCity);
  Iterable<Place> get districts => all.where((p) => p.isDistrict);

  Place? byId(int id) => _byId[id];

  List<Place> citiesOf(int provinceId) =>
      _byParent[provinceId]?.where((p) => p.isCity).toList() ?? const [];

  List<Place> districtsOf(int cityId) =>
      _byParent[cityId]?.where((p) => p.isDistrict).toList() ?? const [];

  /// 城市所属的省；直辖市的城市父级就是它自己那条省级记录。
  Place? provinceOfCity(Place city) {
    final parent = _byId[city.parentId];
    return parent != null && parent.isProvince ? parent : null;
  }
}
