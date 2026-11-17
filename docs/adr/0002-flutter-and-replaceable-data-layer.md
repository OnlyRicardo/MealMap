# Flutter 单代码库 + 可替换的本地数据层

## 背景

产品 Android 优先、未来要上 iOS；开发环境没有 Android Studio，且由 AI agent 在终端里完成绝大多数编写与调试；App 完全离线，但未来可能加云同步。这三件事同时约束技术选型。

## 决定

1. 客户端用 **Flutter**（Dart），一套代码先构建 Android，未来加 iOS target。
2. 数据库用 **drift（SQLite）**，通过 repository 接口访问，UI 不直接碰 SQL。
3. 所有实体使用**稳定字符串 ID（UUID）**，并带 `created_at` / `updated_at`；导出文件带 `format_version`。

## 考虑的方案

- **Kotlin + Compose / KMP**：Android 体验最好，但在没有 IDE 的环境里写 Compose 迭代最慢；且必须从第一天就把数据层放进 `commonMain` 才能兑现跨平台承诺。
- **Expo / React Native**：本机零安装、可用手机上的 Expo Go 预览，但自绘地图最终要 Skia 原生模块，且 agent 无法自行查看真机界面，调试闭环依赖人工转述。
- **Flutter**（选中）：单一 CLI 管理工具链；`flutter test` + golden 测试可以在没有设备的情况下渲染界面供 agent 自查；热重载可用；未来 iOS 复用同一代码库。

## 后果

- 本机需要约 6GB 工具链（JDK + Android SDK + 模拟器镜像），全部装在用户 home 下。
- 7GB 内存是瓶颈：模拟器与 Gradle 需限制并发。
- iOS 出包仍需 Mac 或 EAS 等云端构建。
- 数据层必须与 UI 解耦，否则"预留云同步接口"无法兑现。
