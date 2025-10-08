# Travel Mode Integration Guide

## 已完成的工作

### Flutter Frontend Components ✅
1. **TravelProvider** - 状态管理和API调用
2. **TravelListScreen** - 旅行列表显示
3. **TravelDetailScreen** - 旅行详情（含4个标签页）
4. **TravelCreateDialog** - 创建旅行对话框
5. **Travel Models** - 完整的数据模型定义

### 分支状态
- 当前分支: `flutter/tx-grouping-and-tests`
- 已推送到GitHub: ✅
- PR链接: https://github.com/zensgit/jive-flutter-rust/pull/new/flutter/tx-grouping-and-tests

## 集成步骤

### 1. 添加到主导航 (待完成)

在主导航文件中添加Travel Mode入口：

```dart
// 在主导航中添加
ListTile(
  leading: Icon(Icons.flight_takeoff),
  title: Text('旅行模式'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TravelListScreen(),
      ),
    );
  },
),
```

### 2. 注册Provider (待完成)

在主应用中注册TravelProvider：

```dart
// main.dart 或 provider配置文件
MultiProvider(
  providers: [
    // ... 其他providers
    ChangeNotifierProvider(
      create: (context) => TravelProvider(apiService),
    ),
  ],
  // ...
)
```

### 3. 添加路由 (待完成)

```dart
// 路由配置
routes: {
  '/travel': (context) => TravelListScreen(),
  '/travel/detail': (context) => TravelDetailScreen(
    travelId: ModalRoute.of(context)!.settings.arguments as String,
  ),
}
```

## 后端API状态

### 需要的API端点
- `GET /api/v1/travel/events` - 获取旅行列表
- `POST /api/v1/travel/events` - 创建新旅行
- `GET /api/v1/travel/events/{id}` - 获取旅行详情
- `PUT /api/v1/travel/events/{id}` - 更新旅行
- `DELETE /api/v1/travel/events/{id}` - 删除旅行
- `POST /api/v1/travel/events/{id}/activate` - 激活旅行
- `POST /api/v1/travel/events/{id}/complete` - 完成旅行
- `GET /api/v1/travel/events/{id}/statistics` - 获取统计
- `GET /api/v1/travel/events/{id}/budgets` - 获取预算
- `POST /api/v1/travel/events/{id}/budgets` - 设置预算
- `POST /api/v1/travel/events/{id}/transactions` - 关联交易
- `DELETE /api/v1/travel/events/{id}/transactions` - 取消关联

## 测试步骤

1. **启动后端API**
```bash
cd jive-api
DATABASE_URL="postgresql://postgres:postgres@localhost:5433/jive_money" \
REDIS_URL="redis://localhost:6380" \
API_PORT=8012 \
JWT_SECRET=your-secret-key-dev \
RUST_LOG=info \
SQLX_OFFLINE=true \
cargo run --bin jive-api
```

2. **运行Flutter应用**
```bash
cd jive-flutter
flutter run -d web-server --web-port 3021
```

3. **测试功能**
- 创建新旅行
- 查看旅行列表
- 查看旅行详情
- 设置预算
- 关联交易
- 查看统计

## 待解决问题

1. **Freezed代码生成** - 需要修复其他文件的语法错误后重新生成
2. **主导航集成** - 需要找到正确的导航入口点
3. **API测试** - 需要确保后端API正常运行

## 下一步计划

1. 修复Flutter项目中的语法错误
2. 运行build_runner生成freezed代码
3. 集成到主导航
4. 测试前后端集成
5. 创建Pull Request合并到主分支

## 相关文档

- [Travel Mode设计文档](./TRAVEL_MODE_DESIGN.md)
- [Travel Mode完整设计](./TRAVEL_MODE_COMPLETE_DESIGN.md)