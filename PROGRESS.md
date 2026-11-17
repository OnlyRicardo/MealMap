# 进度

> 每次推进后更新。`✅` 完成，`🚧` 进行中，`⬜` 未开始。

## 当前阶段

v1 开发 · 功能已全部打通（地图/日记/表单/照片/设置/备份），正在做发布前打磨。

## 里程碑

| # | 内容 | 状态 | 备注 |
|---|---|---|---|
| M0 | 规格 / 术语表 / ADR | ✅ | `docs/specs/v1.md`、`GLOSSARY.md`、`docs/adr/` |
| M1 | 工具链（Flutter + Android SDK + 模拟器） | ✅ | 全部在 `~/.local/opt` 与 `~/Android/sdk`，无 sudo |
| M2 | 项目骨架 + 依赖 + 阿里云 Maven 镜像 | ✅ | 包名 `dev.mealmap.app` |
| M3 | 数据层（drift schema / 仓库 / 规则测试） | ✅ | 8 个测试全绿 |
| M4 | 首次 APK 构建 | ✅ | 首次构建耗时 1166s（下 Gradle/AGP/NDK/CMake）；之后增量约 1–2 分钟 |
| M5 | 内置数据集（菜系 / 省市点位） | ✅ | 菜系 22 项；点位 3257 个（133KB），只含点不含边界（ADR-0003） |
| M6 | 记一餐表单（T4） | ✅ | 日期/餐次/城市选择器/菜系/菜品/标签/备注；模拟器实测保存成功 |
| M6b | 照片管线（T5） | ✅ | 多选 ≤9、长边 2048/q80、缩略图 200px、私有目录；设备实测 400×520 → 原图 13.8KB + 缩略图 4.3KB |
| M7 | 美食地图（T6） | ✅ | 墨卡托投影 + 区县背景点（西部按稀疏度放大）；城市点按餐数放大、可点；年份切换；golden 测试 |
| M8 | 美食日历（T7） | ✅ | 月视图（色点/餐数/本月小结）+ 年热力图（只读） |
| M9 | 详情 / 编辑 / 设置（T8/T9） | ✅ | 详情含照片横滑、编辑复用表单、删除二次确认；菜系与标签管理 |
| M10 | 导出 / 导入（T10） | ✅ | data.json + photos/ + thumbs/ 的 zip；版本校验；冲突跳过；4 个测试 |
| M11 | 发布前打磨（T11） | 🚧 | release APK 21.5MB（arm64），无 INTERNET 权限；图标已接入；**已用自有 keystore 签名**；待办：孤儿照片清理 |

## 提交记录

- `8f5216f` docs: 产品规格、术语表与架构决定
- `4ae189f` feat(data): drift schema、MealRepository 与领域规则测试
- `feat(data)`: 内置菜系种子与幂等导入
- `feat(app)`: 应用外壳、Riverpod 注入与首页空态测试
- `c027f0f` feat(data): 行政区点位目录、省份聚合与 ADR-0003
- `1feda71` feat(app): 入口接入 MealMapApp、修复 MainActivity 包名、切到 material_ui
- `f9dac02` feat(map): 城市点阵地图、年份切换与记一餐表单
- `af2ee05` feat(photo): 照片管线（压缩、缩略图、私有目录、上限 9）
- `d61784d` feat(calendar): 美食日历月视图、年热力图、详情/编辑/删除
- `7018d18` feat(settings,backup): 菜系/标签管理与一键移机

## 重要决定

- 内置省界在中国需要审图号、个人无法取得 → 改为**城市点阵**（ADR-0003 取代 ADR-0001）。
- 地图数据：AreaCity（MIT 声明，GCJ-02），只取名称/隶属/坐标，剔除所有 polygon。

## 设备实测记录（模拟器 Pixel 6 / Android 16）

- 记一餐：选城市（省→市）、选菜系、保存后首页计数与地图点同步更新。
- 照片：相册多选 → 压缩写入 `app_flutter/images/`（400×520 原图 13.8KB，缩略图 200×260 4.3KB）。
- 日历：月视图、当天弹层、详情页、编辑/删除入口。
- 备份：导出 zip（`data.json` 2.7KB + 原图 + 缩略图）→ 系统分享面板；把 zip 改动一条记录的 ID 后导入，成功新增 1 餐（3 餐 / 2 天），重复记录跳过。

## 环境事实（踩过的坑）

- `maven.google.com` 在本机不可达（10s 超时）。已在 `android/settings.gradle.kts` 与 `android/build.gradle.kts` 用阿里云镜像 + 官方仓库兜底。
- 机器 7GB 内存：Gradle 限 2 worker / 1.5GB 堆（`~/.local/opt/env.sh`），模拟器需保守配置。
- 无 Android Studio：所有构建走 CLI；界面验证靠 `flutter test` golden + 模拟器截图。
- 无 passwordless sudo：任何需要提权的操作必须交给用户执行。
- **改包名要同步改 Kotlin 包声明**：把 `namespace`/`applicationId` 改成 `dev.mealmap.app` 后，`MainActivity.kt` 还在 `dev.mealmap.mealmap` 下，装到模拟器上直接 `ClassNotFoundException: Didn't find class "dev.mealmap.app.MainActivity"`。已把文件移到 `android/app/src/main/kotlin/dev/mealmap/app/`。
- Flutter 3.50 起 `package:flutter/material.dart` 已标记 deprecated，应改用 `package:material_ui/material_ui.dart`（analyze 会报 info）。全项目已切换。
- **release 构建曾因 AGP 9.3.1 的 lint 自身崩溃失败**（`NoSuchMethodError: JavaDocParser.parseDataItem`，在分析插件里的 `ExifDataCopier.java`）。已在 `android/app/build.gradle.kts` 关掉 `checkReleaseBuilds/abortOnError`，升级 AGP 后可以恢复。
- 签名：`android/app/build.gradle.kts` 在存在 `android/key.properties` 时用 release 签名，否则退回 debug key。keystore 在 `android/keystore/mealmap.jks`（git 忽略），证书 SHA-256 `e35ec61582dfd8d76bc98ae75cc1c37d2c47311ccd4d3db7f132a12a40d1098b`。**这个 jks 必须另行备份**，丢了就无法给已安装用户发升级包。
- 图标：`tool/generate_icon.dart` 用 `package:image` 现画（橙底 + 白碗 + 定位点），`flutter_launcher_icons` 生成 mipmap 与自适应图标。
- 模拟器偶发 `System UI isn't responding`（软件渲染 + 内存紧张），点 Wait 即可；`adb logcat -d -b crash` 看崩溃。
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

1. 设备上走一遍：设置页改名/归档、导出分享、导入恢复。
2. 发布前：应用图标与中文名、README（含截图）、release 构建、飞行模式验收。
3. 可选：孤儿照片清理、省份列表拼音排序、主题饱和度。

## 已知待办 / 取舍

- 表单中途放弃会留下已导入的照片文件（孤儿文件），计划加启动清理（T11）。
- 省份列表按 Unicode 排序（`上海、云南、内蒙古…`），不是拼音序；数据集里没有拼音字段，需要再补。
- 备份导入不做「覆盖」：ID 冲突一律跳过，避免误删新机上的记录。
- 主题色偏灰：`ColorScheme.fromSeed(0xFFE8590C)` 在 Material 3 下饱和度被压低，发布前调 `dynamicSchemeVariant`。
