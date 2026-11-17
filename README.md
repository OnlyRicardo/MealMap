# MealMap（工作名）

记录「什么时候、在哪里、吃了什么」的个人饮食日志 App。

- **美食地图**：按 Meal 数量给省份着色，城市出气泡，可按年份筛选。
- **美食日历**：月视图可点开某天查看当天记录，年视图是只读热力图。
- **完全离线**：数据存在本机 SQLite，照片存在 App 私有目录，不需要账号、不需要网络。
- **一键移机**：导出带照片的 zip，通过系统分享传到新手机后导入。

## 文档

- [规格](docs/specs/v1.md)
- [术语表](GLOSSARY.md)
- 架构决定：[0001 抽象行政区地图](docs/adr/0001-abstract-admin-map.md) · [0002 Flutter 与可替换数据层](docs/adr/0002-flutter-and-replaceable-data-layer.md)

## 开发

> 工具链说明见 `docs/specs/v1.md` 与 ADR-0002。本项目在无 Android Studio 的环境中开发。

```bash
flutter pub get
flutter test
flutter run
```

## 许可证

MIT，见 [LICENSE](LICENSE)。
