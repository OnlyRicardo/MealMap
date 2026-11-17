import 'package:material_ui/material_ui.dart';

/// 菜系的固定配色。
///
/// 用字符编码求和而不是 `hashCode`，保证同一菜系在不同次启动里颜色一致。
const _palette = <Color>[
  Color(0xFFC0392B),
  Color(0xFFE67E22),
  Color(0xFFD4A017),
  Color(0xFF27AE60),
  Color(0xFF16A085),
  Color(0xFF2980B9),
  Color(0xFF8E44AD),
  Color(0xFFD35400),
  Color(0xFF7F8C8D),
  Color(0xFFC2185B),
  Color(0xFF0097A7),
  Color(0xFF5D4037),
];

Color cuisineColor(String cuisineId) {
  var sum = 0;
  for (final unit in cuisineId.codeUnits) {
    sum = (sum * 31 + unit) % 1000003;
  }
  return _palette[sum % _palette.length];
}
