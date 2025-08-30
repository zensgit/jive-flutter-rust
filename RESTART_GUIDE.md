# Jive Money 快速重启指南

## 📱 应用配置
- **Flutter 端口**: 固定为 `3021`
- **主应用文件**: `lib/main_simple.dart`
- **访问地址**: http://localhost:3021

## 🚀 快速重启服务

### 方法1: 命令行快速重启
```bash
cd /home/zou/SynologyDrive/github/jive-flutter-rust
./start.sh restart
```

### 方法2: 使用交互式菜单
```bash
cd /home/zou/SynologyDrive/github/jive-flutter-rust
./start.sh

# 然后选择 "8) 快速重启 Flutter"
```

## 🛠️ 其他有用命令

### 查看服务状态
```bash
./start.sh status
```

### 停止所有服务
```bash
./start.sh stop
```

### 开发模式 (热重载)
```bash
./start.sh dev
```

### 完整启动 (检查依赖)
```bash
./start.sh start
```

## 📋 功能特点

### ✅ 快速重启功能
- 自动停止现有Flutter进程
- 强制清理占用的端口
- 重新启动应用
- 显示启动状态和访问地址

### 🎯 固定配置
- 端口固定为3021，不需要每次配置
- 使用优化的`main_simple.dart`入口
- 包含完整的标签管理功能

### 🔧 自动化处理
- 自动检测和终止占用端口的进程
- 智能等待进程完全结束
- 显示详细的启动状态信息

## 📚 使用示例

```bash
# 快速重启服务
./start.sh restart

# 输出示例:
# === 快速重启 Flutter 应用 ===
# 正在重新启动 Flutter 应用...
# ✓ Flutter 应用重启成功 (PID: 12345)
#   访问地址: http://localhost:3021
# 等待应用启动...
# ✅ 应用启动成功!
```

## 🎉 标签管理功能

应用现在包含完整的标签管理系统:
- ✅ 创建和编辑标签
- ✅ 标签分组管理  
- ✅ 颜色和图标支持
- ✅ 使用统计和归档
- ✅ 搜索和筛选

访问 http://localhost:3021 后，在管理菜单中找到"标签管理"即可使用全部功能。