# 发布签名

App 的包名是 `dev.mealmap.app`。装到手机上长期使用时，必须用**自己的密钥**签名；换密钥会导致旧版本无法覆盖安装，记录也就「断档」了。所以这一步只做一次，密钥库要备份好。

## 1. 生成密钥库（需要你执行）

`keytool` 会提示输入密码和姓名等信息。**密码自己记牢**，丢了就无法再发同名升级包。

```bash
cd /home/wxx-linux/project/p1
mkdir -p android/keystore

$JAVA_HOME/bin/keytool -genkeypair -v \
  -keystore android/keystore/mealmap.jks \
  -alias mealmap \
  -keyalg RSA -keysize 4096 -validity 10950 \
  -dname "CN=MealMap, OU=Personal, O=MealMap, L=, ST=, C=CN"
```

> `$JAVA_HOME` 需要先 `source ~/.local/opt/env.sh`；或者直接用 `~/.local/opt/jdk-17/bin/keytool`。

## 2. 告诉 Gradle 密码

```bash
cd /home/wxx-linux/project/p1
cp android/key.properties.example android/key.properties
# 用编辑器填 storePassword / keyPassword / keyAlias / storeFile
```

`storeFile` 相对于 `android/app/`，默认示例是 `../keystore/mealmap.jks`。

`android/key.properties` 和 `*.jks` 都已在 `.gitignore` 里，不会被提交。

## 3. 出包

```bash
source ~/.local/opt/env.sh
flutter build apk --release --target-platform android-arm64
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

如果 `key.properties` 不存在，Gradle 会退回 debug 签名（只为方便本机验证，不要用它发版）。

## 4. 检查

```bash
$ANDROID_HOME/build-tools/37.0.0/apksigner verify --print-certs \
  build/app/outputs/flutter-apk/app-release.apk
```

应该看到你的证书指纹，而不是 `Android Debug`。
