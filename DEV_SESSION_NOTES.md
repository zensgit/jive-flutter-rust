## 会话恢复与开发速览 (Session Resume Guide)

最后更新时间: $(date)

### 环境 / 通道
- 本地 Flutter SDK: `~/flutter-sdk`
- 推荐通道: **stable** （若当前不是：`flutter channel stable && flutter upgrade`）
- 激活本地 SDK (必须 *source*):
  ```bash
  source scripts/activate_local_flutter_env.sh ~/flutter-sdk
  ```

### 启动顺序
1. 激活本地 Flutter：
   ```bash
   source scripts/activate_local_flutter_env.sh ~/flutter-sdk
   ```
2. 前端：
   ```bash
   cd jive-flutter
   flutter pub get
   flutter run -d chrome --web-port 3021
   # 或备用
   flutter run -d web-server --web-port 3021 --web-renderer html
   ```
3. 后端：
   ```bash
   ./jive-manager.sh api_start_dev
   ./jive-manager.sh health_check
   ```
4. 浏览器访问: http://localhost:3021 （必要时无痕）
5. 若页面空白：检查控制台 + Network 是否 `main.dart.js` 200。

### 已完成工作概要
- 依赖安全升级：`retrofit`, `cached_network_image`, `shared_preferences`, `crypto`, `logger`, `path_provider`, 等。
- 解决 `hive_generator` 与 `json_serializable` / `riverpod_generator` 版本冲突（保持 `json_serializable 6.8.0` & `riverpod_generator 2.4.0`）。
- 新增脚本：
  - `scripts/use_local_flutter.sh` （一次性切换）
  - `scripts/activate_local_flutter_env.sh` （每次会话激活）
- Web index.html 多轮修复；当前建议 **stable 模板** + 可选加入 `right_click_dev.js`。
- 修复 `_baseUrl` 未定义、汇率/加密价格服务接口引用问题。
- 减少 Flutter Loader 在 master 通道的 buildConfig 报错（建议使用 stable）。

### 待办（可选优先级）
- [ ] 登录后懒加载汇率（替代启动即全量刷新）
- [ ] 增量补拉缺失币种 `ensureRates(targets: [...])`
- [ ] 汇率刷新节流（10 分钟有效期）
- [ ] 去除/收敛调试 `print()` → 使用 `logger` 可控输出
- [ ] `go_router` 12.x → 16.x 升级（新 API 需适配）
- [ ] `fl_chart` 0.66.x → 1.x 重大变更
- [ ] `retrofit_generator` 8.x → 10.x（同步 retrofit 注解差异）
- [ ] very_good_analysis 5.x → 9.x（集中修复 lint）
- [ ] 懒加载 + 汇率页面补拉策略实现后删除旧批量加载逻辑

### 常用命令速查
```bash
# 清理 + 重新获取依赖
flutter clean && flutter pub get

# 代码生成（有 model / retrofit / freezed 时）
flutter pub run build_runner build --delete-conflicting-outputs

# 后端 API (dev)
./jive-manager.sh api_start_dev

# 查看服务健康
./jive-manager.sh health_check
```

### 常见问题排查
| 现象 | 排查点 | 解决 |
|------|--------|------|
| Web 空白 / 卡加载 | `main.dart.js` 404 或 SW 缓存 | 无痕模式 / 清 SW / stable 通道 |
| `FlutterLoader.load requires _flutter.buildConfig` | master 通道不兼容 | 切 stable / 使用官方模板 |
| 依赖冲突 source_gen | `hive_generator` + `json_serializable` + `riverpod_generator` | 保持 json_serializable 6.8.0 & riverpod_generator 2.4.0 |
| `_baseUrl` 未定义 | Crypto / Exchange 服务旧代码 | 已补 getter，若再现清理缓存重新编译 |
| 频繁汇率日志 | 启动即刷新 + 多 Provider 重建 | 引入懒加载 + 缓存节流（待办） |

### 未来改进建议
- 将汇率数据缓存结构抽离为单例/仓储层，Provider 只读。
- 为登录事件（AuthEvents.authorized）挂接 `ensureRates()` 初次拉取。
- 添加 `scripts/build_web_release.sh` 封装 release & size analyze。

### 快速恢复 TL;DR
```bash
cd <repo-root>
source scripts/activate_local_flutter_env.sh ~/flutter-sdk
cd jive-flutter && flutter pub get && flutter run -d chrome --web-port 3021
```

---
如需恢复 master / 测试最新 Web Loader：切回 master，恢复自适应启动脚本，但建议先在分支中进行。

