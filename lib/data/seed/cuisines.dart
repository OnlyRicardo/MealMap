import '../../domain/models.dart';

/// 内置菜系：中国按「菜系」而非省级行政区划分（川菜可以出现在任何城市），
/// 国外按饮食文化圈粗分。用户可以在此基础上新增，或归档掉不吃的。
const List<CuisineSeed> builtinCuisines = [
  CuisineSeed(id: 'sichuan', name: '川菜', sortOrder: 10),
  CuisineSeed(id: 'cantonese', name: '粤菜', sortOrder: 20),
  CuisineSeed(id: 'hunan', name: '湘菜', sortOrder: 30),
  CuisineSeed(id: 'shandong', name: '鲁菜', sortOrder: 40),
  CuisineSeed(id: 'jiangsu', name: '苏菜', sortOrder: 50),
  CuisineSeed(id: 'zhejiang', name: '浙菜', sortOrder: 60),
  CuisineSeed(id: 'fujian', name: '闽菜', sortOrder: 70),
  CuisineSeed(id: 'anhui', name: '徽菜', sortOrder: 80),
  CuisineSeed(id: 'northeast', name: '东北菜', sortOrder: 90),
  CuisineSeed(id: 'northwest', name: '西北菜', sortOrder: 100),
  CuisineSeed(id: 'yunguichuan', name: '云贵菜', sortOrder: 110),
  CuisineSeed(id: 'beijing', name: '京菜', sortOrder: 120),
  CuisineSeed(id: 'shanghai', name: '本帮菜', sortOrder: 130),
  CuisineSeed(id: 'chaoshan_hakka', name: '潮汕客家菜', sortOrder: 140),
  CuisineSeed(id: 'japanese', name: '日料', sortOrder: 150),
  CuisineSeed(id: 'korean', name: '韩餐', sortOrder: 160),
  CuisineSeed(id: 'southeast_asian', name: '东南亚菜', sortOrder: 170),
  CuisineSeed(id: 'south_asian', name: '南亚菜', sortOrder: 180),
  CuisineSeed(id: 'middle_eastern', name: '中东菜', sortOrder: 190),
  CuisineSeed(id: 'western', name: '意法西餐', sortOrder: 200),
  CuisineSeed(id: 'latin_american', name: '拉美菜', sortOrder: 210),
  CuisineSeed(id: 'fast_food_other', name: '快餐/其他', sortOrder: 220),
];
