// 生成应用图标（一次性工具，改图标时重新跑）。
//
//   dart run tool/generate_icon.dart
//
// 输出：
//   assets/icon/app_icon.png            1024×1024，橙色底 + 白碗 + 定位点
//   assets/icon/app_icon_foreground.png 1024×1024，透明底（自适应图标前景，留安全边距）
//
// 手绘而不是用设计工具：图标很简单，生成脚本可版本化、可复现。
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

final _orange = img.ColorRgba8(0xE8, 0x59, 0x0C, 255);
final _white = img.ColorRgba8(0xFF, 0xFF, 0xFF, 0xFF);

void main() {
  const size = 1024;

  final scene = _drawScene(size);

  final background = img.Image(width: size, height: size, numChannels: 4);
  img.fill(background, color: _orange);
  _roundCorners(background, 190);
  img.compositeImage(background, scene);
  File('assets/icon/app_icon.png')
      .writeAsBytesSync(img.encodePng(background, level: 9));

  // 自适应图标：内容缩到 62%，四周留出系统裁切的安全区。
  final foreground = img.Image(width: size, height: size, numChannels: 4);
  final scaled = img.copyResize(
    scene,
    width: (size * 0.62).round(),
    height: (size * 0.62).round(),
    interpolation: img.Interpolation.cubic,
  );
  final offset = ((size - scaled.width) / 2).round();
  img.compositeImage(foreground, scaled, dstX: offset, dstY: offset);
  File('assets/icon/app_icon_foreground.png')
      .writeAsBytesSync(img.encodePng(foreground, level: 9));

  stdout.writeln('icons written to assets/icon/');
}

/// 白色碗 + 碗上方一枚定位点（碗口即定位针的尖端）。
img.Image _drawScene(int size) {
  final scene = img.Image(width: size, height: size, numChannels: 4);
  const cx = 512;

  // 碗身：圆形，切掉上半部分，只留下半圆。
  img.fillCircle(scene, x: cx, y: 700, radius: 268, color: _white);
  for (var y = 0; y < 640; y++) {
    for (var x = 0; x < size; x++) {
      scene.setPixelRgba(x, y, 0, 0, 0, 0);
    }
  }

  // 碗沿。
  img.fillRect(scene, x1: 214, y1: 596, x2: 810, y2: 676, color: _white);
  img.fillCircle(scene, x: 214, y: 636, radius: 40, color: _white);
  img.fillCircle(scene, x: 810, y: 636, radius: 40, color: _white);

  // 定位点：圆 + 朝下的尖。
  img.fillCircle(scene, x: cx, y: 330, radius: 152, color: _white);
  img.fillPolygon(
    scene,
    vertices: [
      img.Point(512, 612),
      img.Point(388, 332),
      img.Point(636, 332),
    ],
    color: _white,
  );
  _clearCircle(scene, cx, 330, 64);
  return scene;
}

void _clearCircle(img.Image image, int cx, int cy, int radius) {
  final r2 = radius * radius;
  for (var y = math.max(0, cy - radius); y <= math.min(image.height - 1, cy + radius); y++) {
    for (var x = math.max(0, cx - radius); x <= math.min(image.width - 1, cx + radius); x++) {
      final dx = x - cx;
      final dy = y - cy;
      if (dx * dx + dy * dy <= r2) {
        image.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
  }
}

void _roundCorners(img.Image image, int radius) {
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final dx = x < radius
          ? radius - x
          : (x > image.width - radius - 1 ? x - (image.width - radius - 1) : 0);
      final dy = y < radius
          ? radius - y
          : (y > image.height - radius - 1 ? y - (image.height - radius - 1) : 0);
      if (dx > 0 && dy > 0 && dx * dx + dy * dy > radius * radius) {
        image.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
  }
}
