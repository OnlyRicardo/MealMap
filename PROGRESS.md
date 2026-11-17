# 进度

> 每次推进后更新。`✅` 完成，`🚧` 进行中，`⬜` 未开始。

## 当前阶段

v1 开发 · 数据层完成，正在打通构建与内置数据集。

## 里程碑

| # | 内容 | 状态 | 备注 |
|---|---|---|---|
| M0 | 规格 / 术语表 / ADR | ✅ | `docs/specs/v1.md`、`GLOSSARY.md`、`docs/adr/` |
| M1 | 工具链（Flutter + Android SDK + 模拟器） | ✅ | 全部在 `~/.local/opt` 与 `~/Android/sdk`，无 sudo |
| M2 | 项目骨架 + 依赖 + 阿里云 Maven 镜像 | ✅ | 包名 `dev.mealmap.app` |
| M3 | 数据层（drift schema / 仓库 / 规则测试） | ✅ | 8 个测试全绿 |
| M4 | 首次 APK 构建 | ✅ | 首次构建耗时 1166s（下 Gradle/AGP/NDK/CMake）；之后增量约 1–2 分钟 |
| M5 | 内置数据集（菜系 / 省市点位） | ✅ | 菜系 22 项；点位 3257 个（133KB），只含点不含边界（ADR-0003） |
| M6 | 记一餐表单 + 照片管线 | ⬜ | |
| M7 | 美食地图 | ⬜ | |
| M8 | 美食日历 | ⬜ | |
| M9 | 详情 / 编辑 / 设置 | ⬜ | |
| M10 | 导出 / 导入 / 一键移机 | ⬜ | |
| M11 | 发布前打磨 | ⬜ | |

## 提交记录

- `8f5216f` docs: 产品规格、术语表与架构决定
- `4ae189f` feat(data): drift schema、MealRepository 与领域规则测试
- `feat(data)`: 内置菜系种子与幂等导入
- `feat(app)`: 应用外壳、Riverpod 注入与首页空态测试
- `feat(data)`: 行政区点位目录 + 省份聚合 + ADR-0003

## 重要决定

- 内置省界在中国需要审图号、个人无法取得 → 改为**城市点阵**（ADR-0003 取代 ADR-0001）。
- 地图数据：AreaCity（MIT 声明，GCJ-02），只取名称/隶属/坐标，剔除所有 polygon。

## 环境事实（踩过的坑）

- `maven.google.com` 在本机不可达（10s 超时）。已在 `android/settings.gradle.kts` 与 `android/build.gradle.kts` 用阿里云镜像 + 官方仓库兜底。
- 机器 7GB 内存：Gradle 限 2 worker / 1.5GB 堆（`~/.local/opt/env.sh`），模拟器需保守配置。
- 无 Android Studio：所有构建走 CLI；界面验证靠 `flutter test` golden + 模拟器截图。
- 无 passwordless sudo：任何需要提权的操作必须交给用户执行。
- **改包名要同步改 Kotlin 包声明**：把 `namespace`/`applicationId` 改成 `dev.mealmap.app` 后，`MainActivity.kt` 还在 `dev.mealmap.mealmap` 下，装到模拟器上直接 `ClassNotFoundException: Didn't find class "dev.mealmap.app.MainActivity"`。已把文件移到 `android/app/src/main/kotlin/dev/mealmap/app/`。
- Flutter 3.50 起 `package:flutter/material.dart` 已标记 deprecated，应改用 `package:material_ui/material_ui.dart`（analyze 会报 info）。全项目已切换。
- 模拟器验证命令：`emulator -avd mealmap -no-window -no-audio -gpu swiftshader_indirect &`，`adb exec-out screencap -p > shot.png`，崩溃堆栈看 `adb logcat -d -b crash`。

## 怎么继续

```bash
source ~/.local/opt/env.sh
cd /home/wxx-linux/project/p1
flutter test          # 数据层
flutter build apk --debug
emulator -avd mealmap -no-window -no-audio -gpu swiftshader_indirect &
flutter run
```

## 下一步（按顺序）

1. 等 M4 构建通过，替换默认计数器页面为应用外壳。
2. 确认省市 / GeoJSON 数据来源与许可证，落进 `assets/`。
3. T4 记一餐表单 → T5 照片管线。
