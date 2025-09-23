# Flutter 完整安装指南

## 📋 目录
1. [系统要求](#系统要求)
2. [Windows 安装](#windows-安装)
3. [macOS 安装](#macos-安装)
4. [Linux 安装](#linux-安装)
5. [环境配置](#环境配置)
6. [验证安装](#验证安装)
7. [常见问题](#常见问题)

---

## 系统要求

### 最低配置
- **磁盘空间**: 2.8 GB (不包括 IDE/工具)
- **内存**: 4 GB RAM (推荐 8 GB)
- **工具**: Git, IDE (VS Code/Android Studio)

### 支持的操作系统
- Windows 10/11 (64-bit)
- macOS (64-bit, 10.14 或更高)
- Linux (64-bit)

---

## Windows 安装

### 方法一：使用安装程序（推荐）

1. **下载 Flutter SDK**
   ```
   https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.16.5-stable.zip
   ```

2. **解压到指定目录**
   ```powershell
   # 推荐路径（避免需要权限的目录）
   C:\src\flutter
   # 或
   C:\Users\{你的用户名}\flutter
   ```

3. **添加到环境变量**
   - 打开"系统属性" → "环境变量"
   - 在用户变量中找到 `Path`
   - 添加 `C:\src\flutter\bin`

4. **安装依赖**
   ```powershell
   # 以管理员身份运行 PowerShell
   
   # 安装 Git
   winget install --id Git.Git -e --source winget
   
   # 安装 Android Studio
   winget install --id Google.AndroidStudio -e --source winget
   ```

### 方法二：使用 Chocolatey

```powershell
# 安装 Chocolatey（如果未安装）
Set-ExecutionPolicy Bypass -Scope Process -Force; 
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; 
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# 安装 Flutter
choco install flutter

# 安装相关工具
choco install git
choco install android-studio
choco install vscode
```

---

## macOS 安装

### 方法一：手动安装

1. **下载 Flutter SDK**
   ```bash
   cd ~/development
   wget https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.16.5-stable.zip
   unzip flutter_macos_3.16.5-stable.zip
   ```

2. **添加到 PATH**
   ```bash
   # 编辑 shell 配置文件
   # 对于 zsh (默认)
   echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.zshrc
   source ~/.zshrc
   
   # 对于 bash
   echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.bash_profile
   source ~/.bash_profile
   ```

3. **安装 Xcode**
   ```bash
   # 从 App Store 安装 Xcode
   # 或使用命令行
   xcode-select --install
   
   # 接受许可协议
   sudo xcodebuild -license accept
   ```

4. **安装 CocoaPods**
   ```bash
   sudo gem install cocoapods
   ```

### 方法二：使用 Homebrew（推荐）

```bash
# 安装 Homebrew（如果未安装）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 添加 Flutter 仓库
brew tap dart-lang/dart

# 安装 Flutter
brew install --cask flutter

# 安装相关工具
brew install --cask android-studio
brew install --cask visual-studio-code
brew install cocoapods
```

---

## Linux 安装

### Ubuntu/Debian 系统

1. **安装依赖**
   ```bash
   sudo apt update
   sudo apt install -y curl git unzip xz-utils zip libglu1-mesa
   
   # 如果要开发 Linux 桌面应用
   sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev
   ```

2. **下载 Flutter**
   ```bash
   cd ~
   wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.16.5-stable.tar.xz
   tar xf flutter_linux_3.16.5-stable.tar.xz
   ```

3. **添加到 PATH**
   ```bash
   echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
   source ~/.bashrc
   ```

4. **安装 Android Studio**
   ```bash
   # 使用 snap
   sudo snap install android-studio --classic
   
   # 或下载安装包
   wget https://redirector.gvt1.com/edgedl/android/studio/ide-zips/2023.1.1.26/android-studio-2023.1.1.26-linux.tar.gz
   tar -xzf android-studio-*.tar.gz
   sudo mv android-studio /opt/
   /opt/android-studio/bin/studio.sh
   ```

### Arch Linux

```bash
# 使用 AUR
yay -S flutter

# 或使用 pacman（需要添加中文社区仓库）
sudo pacman -S flutter
```

### Fedora

```bash
# 安装依赖
sudo dnf install -y bash curl file git unzip which xz zip mesa-libGLU

# 下载并安装 Flutter（同 Ubuntu 步骤）
```

---

## 环境配置

### 1. 配置 Android 开发环境

```bash
# 运行 Flutter doctor
flutter doctor

# 接受 Android 许可
flutter doctor --android-licenses

# 安装 Android SDK 命令行工具
# 在 Android Studio 中：
# Settings → Appearance & Behavior → System Settings → Android SDK
# SDK Tools 选项卡 → 勾选 "Android SDK Command-line Tools"
```

### 2. 配置 iOS 开发环境（仅 macOS）

```bash
# 安装 iOS 模拟器
open -a Simulator

# 部署到 iOS 设备需要
brew install ios-deploy

# 安装必要的证书
flutter doctor --ios-setup
```

### 3. 配置 Web 开发环境

```bash
# Flutter 3.0+ 默认支持 Web
flutter config --enable-web

# 安装 Chrome（用于调试）
# Windows/Mac: 从官网下载
# Linux:
sudo apt install google-chrome-stable  # Ubuntu/Debian
```

### 4. 配置桌面开发环境

```bash
# Windows 桌面
flutter config --enable-windows-desktop

# macOS 桌面
flutter config --enable-macos-desktop

# Linux 桌面
flutter config --enable-linux-desktop
```

---

## 验证安装

### 1. 检查 Flutter 版本

```bash
flutter --version
```

预期输出：
```
Flutter 3.16.5 • channel stable • https://github.com/flutter/flutter.git
Framework • revision 78666c8dc5 (2 weeks ago) • 2023-12-19 10:14:14 -0800
Engine • revision 3f3e560236
Tools • Dart 3.2.3 • DevTools 2.28.4
```

### 2. 运行诊断

```bash
flutter doctor -v
```

理想输出示例：
```
[✓] Flutter (Channel stable, 3.16.5, on macOS 14.0 23A344 darwin-arm64)
[✓] Android toolchain - develop for Android devices
[✓] Xcode - develop for iOS and macOS
[✓] Chrome - develop for the web
[✓] Android Studio
[✓] VS Code
[✓] Connected device (2 available)
[✓] Network resources
```

### 3. 创建测试项目

```bash
# 创建新项目
flutter create test_app
cd test_app

# 运行项目
flutter run

# 指定设备运行
flutter run -d chrome     # Web
flutter run -d windows    # Windows
flutter run -d macos      # macOS
flutter run -d linux      # Linux
```

---

## IDE 配置

### VS Code

1. **安装 Flutter 扩展**
   ```bash
   code --install-extension Dart-Code.flutter
   code --install-extension Dart-Code.dart-code
   ```

2. **配置设置**
   ```json
   {
     "dart.flutterSdkPath": "~/flutter",
     "editor.formatOnSave": true,
     "dart.lineLength": 120,
     "[dart]": {
       "editor.rulers": [120]
     }
   }
   ```

### Android Studio

1. **安装 Flutter 插件**
   - File → Settings → Plugins
   - 搜索 "Flutter" 并安装
   - 重启 IDE

2. **配置 Flutter SDK**
   - File → Settings → Languages & Frameworks → Flutter
   - 设置 Flutter SDK 路径

### IntelliJ IDEA

```bash
# 同 Android Studio 配置
```

---

## 中国用户特别说明

### 配置镜像源

```bash
# 设置环境变量
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# 永久设置（添加到 ~/.bashrc 或 ~/.zshrc）
echo 'export PUB_HOSTED_URL=https://pub.flutter-io.cn' >> ~/.bashrc
echo 'export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn' >> ~/.bashrc
```

### Windows 用户设置

```powershell
# PowerShell
[Environment]::SetEnvironmentVariable("PUB_HOSTED_URL", "https://pub.flutter-io.cn", "User")
[Environment]::SetEnvironmentVariable("FLUTTER_STORAGE_BASE_URL", "https://storage.flutter-io.cn", "User")
```

---

## 常见问题

### 1. "flutter: command not found"

**解决方案**：
```bash
# 确认 PATH 设置正确
echo $PATH

# 重新加载配置
source ~/.bashrc  # 或 ~/.zshrc

# 直接运行
~/flutter/bin/flutter doctor
```

### 2. Android licenses 问题

**解决方案**：
```bash
flutter doctor --android-licenses
# 一路输入 y 接受所有许可
```

### 3. VS Code 找不到设备

**解决方案**：
```bash
# 重启 ADB
adb kill-server
adb start-server

# 刷新设备列表
flutter devices
```

### 4. iOS 开发证书问题

**解决方案**：
```bash
# 打开 Xcode，创建一个新项目
# 配置开发团队和证书
# 然后重新运行 Flutter 项目
```

### 5. Web 开发 CORS 问题

**解决方案**：
```bash
# 使用以下命令运行，禁用 CORS
flutter run -d chrome --web-browser-flag "--disable-web-security"
```

---

## 升级 Flutter

```bash
# 查看可用版本
flutter channel

# 切换到稳定版本
flutter channel stable

# 升级 Flutter
flutter upgrade

# 强制升级
flutter upgrade --force

# 降级到特定版本
flutter downgrade v3.16.0
```

---

## 卸载 Flutter

### Windows
1. 删除 Flutter SDK 文件夹
2. 从环境变量中移除 Flutter 路径

### macOS/Linux
```bash
# 删除 Flutter SDK
rm -rf ~/flutter

# 删除配置（从 .bashrc/.zshrc 中删除相关行）
```

---

## 🎯 快速开始 Jive 项目

安装完 Flutter 后，运行 Jive 项目：

```bash
# 1. 克隆项目
git clone https://github.com/your-repo/jive-flutter-rust.git
cd jive-flutter-rust

# 2. 安装 Rust（如果未安装）
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 3. 安装项目依赖
cd jive-flutter
flutter pub get

# 4. 构建 Rust 后端
cd ../jive-core
cargo build --release

# 5. 运行项目
cd ../jive-flutter
flutter run

# 或指定平台
flutter run -d chrome    # Web
flutter run -d macos     # macOS
flutter run -d windows   # Windows
```

---

## 📚 学习资源

- [Flutter 官方文档](https://flutter.dev/docs)
- [Flutter 中文文档](https://flutter.cn/docs)
- [Flutter 实战](https://book.flutterchina.club/)
- [Dart 语言教程](https://dart.dev/guides)
- [Flutter Gallery](https://gallery.flutter.dev/)

---

## 💡 提示

1. **使用 FVM 管理多版本**
   ```bash
   dart pub global activate fvm
   fvm install 3.16.5
   fvm use 3.16.5
   ```

2. **加速包下载**
   ```bash
   # 使用代理
   export https_proxy=http://127.0.0.1:7890
   export http_proxy=http://127.0.0.1:7890
   ```

3. **清理缓存**
   ```bash
   flutter clean
   flutter pub cache clean
   ```

---

祝您安装顺利！如有问题，请查看 [Flutter 官方故障排除指南](https://flutter.dev/docs/development/tools/sdk/troubleshoot)。