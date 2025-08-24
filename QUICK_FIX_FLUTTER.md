# Flutter 环境快速修复指南

## 当前状态
✅ Flutter 3.16.5 已安装
✅ Linux 工具链就绪  
✅ VS Code 已安装
❌ Android SDK 缺失
❌ Chrome 未安装

## 快速修复方案

### 方案 A：自动修复（推荐）
```bash
cd ~/SynologyDrive/github/jive-flutter-rust
chmod +x fix_flutter_setup.sh
./fix_flutter_setup.sh
```

### 方案 B：手动安装

#### 1. 安装 Android SDK（命令行方式）
```bash
# 安装 Android Studio（包含 SDK）
sudo snap install android-studio --classic

# 或者只安装 SDK
mkdir -p ~/Android/Sdk
cd /tmp
wget https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip
unzip commandlinetools-linux-9477386_latest.zip
mkdir -p ~/Android/Sdk/cmdline-tools/latest
mv cmdline-tools/* ~/Android/Sdk/cmdline-tools/latest/
```

#### 2. 配置环境变量
```bash
echo 'export ANDROID_HOME=$HOME/Android/Sdk' >> ~/.bashrc
echo 'export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin' >> ~/.bashrc
echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools' >> ~/.bashrc
source ~/.bashrc
```

#### 3. 安装 SDK 组件
```bash
sdkmanager "platform-tools" "platforms;android-33" "build-tools;33.0.0"
```

#### 4. 接受许可证
```bash
flutter doctor --android-licenses
# 一路输入 y
```

#### 5. 安装 Chrome
```bash
# 方法 1：使用 apt
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
sudo sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
sudo apt update
sudo apt install google-chrome-stable

# 方法 2：直接下载 deb 包
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i google-chrome-stable_current_amd64.deb
sudo apt --fix-broken install
```

## 不需要 Android SDK 的方案

由于您已经有 Linux 工具链，可以直接运行 Flutter 应用作为 Linux 桌面应用：

### 运行 Jive 项目（Linux 桌面版）
```bash
cd ~/SynologyDrive/github/jive-flutter-rust/jive-flutter
flutter pub get
flutter run -d linux
```

### 运行 Jive 项目（Web 版）
如果安装了 Chrome：
```bash
flutter run -d chrome
```

如果没有 Chrome，可以构建 Web 版本并用任何浏览器打开：
```bash
flutter build web
# 然后用 Python 启动简单服务器
cd build/web
python3 -m http.server 8080
# 打开浏览器访问 http://localhost:8080
```

## 最简方案（无需 Android SDK 和 Chrome）

```bash
# 1. 进入项目目录
cd ~/SynologyDrive/github/jive-flutter-rust/jive-flutter

# 2. 获取依赖
flutter pub get

# 3. 运行 Linux 桌面版
flutter run -d linux

# 或构建发布版
flutter build linux --release
# 可执行文件位于: build/linux/x64/release/bundle/jive_flutter
```

## 验证安装
```bash
flutter doctor
```

## 故障排除

### 问题：flutter doctor 仍显示 Android SDK 缺失
**解决**：确保环境变量正确设置
```bash
echo $ANDROID_HOME  # 应该显示 /home/zou/Android/Sdk
which sdkmanager    # 应该显示 sdkmanager 路径
```

### 问题：Chrome 安装失败
**解决**：使用 Firefox 代替
```bash
flutter run -d web-server
# 然后在 Firefox 中打开显示的 URL
```

### 问题：Linux 桌面应用运行失败
**解决**：安装缺失的依赖
```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev
```

## 推荐运行顺序

1. **先试 Linux 桌面版**（最简单，无需额外安装）
   ```bash
   flutter run -d linux
   ```

2. **如果需要 Web 版**
   - 安装 Chrome 后：`flutter run -d chrome`
   - 或用现有浏览器：`flutter build web && cd build/web && python3 -m http.server`

3. **如果需要 Android 开发**
   - 运行 `./fix_flutter_setup.sh` 安装 Android SDK
   - 或安装 Android Studio（图形界面更友好）

---

**立即可用的命令**（无需安装任何额外组件）：
```bash
cd ~/SynologyDrive/github/jive-flutter-rust/jive-flutter
flutter pub get
flutter run -d linux
```

这将启动 Jive 作为原生 Linux 桌面应用！