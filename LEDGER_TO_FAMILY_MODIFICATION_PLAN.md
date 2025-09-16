# Ledger 系统改造为 Family 架构 - 实施计划

## 📋 现状分析

### 已有组件
1. **前端UI** ✅
   - `settings_screen.dart`: 账本管理、切换、共享UI
   - `dashboard_screen.dart`: 账本切换器UI
   - `ledger_provider.dart`: 状态管理

2. **API端点** ✅
   - `/api/v1/ledgers`: CRUD操作
   - `/api/v1/ledgers/current`: 当前账本
   - `/api/v1/ledgers/:id/share`: 分享功能

3. **后端实现** ✅
   - `handlers/ledgers.rs`: API处理器
   - 数据库表: ledgers, family_members

## 🎯 改造方案：最小化改动，最大化效果

### 核心策略
**保留所有现有代码，仅做术语映射和小幅优化**

## 📝 具体改动计划

### 1️⃣ 前端改动（最小化）

#### A. 术语映射（仅改显示文本）
```dart
// settings_screen.dart - 仅改文本
- title: '账本管理' → '家庭管理'
- subtitle: '创建和管理多个账本' → '创建和管理多个家庭'
- title: '账本切换' → '家庭切换'
- title: '账本共享' → '家庭成员'
- subtitle: '与家人或团队共享账本' → '邀请家人加入'

// dashboard_screen.dart
- tooltip: '切换账本' → '切换家庭'
```

#### B. 图标优化
```dart
// 根据ledger.type显示不同图标
IconData _getLedgerIcon(String type) {
  switch (type) {
    case 'personal': return Icons.person;
    case 'family': return Icons.family_restroom; // 已实现
    case 'business': return Icons.business;
    default: return Icons.book;
  }
}
```

#### C. 创建账本时默认类型
```dart
// 在创建对话框中
Future<void> createLedger() async {
  final ledger = Ledger(
    name: nameController.text,
    type: LedgerType.family,  // 默认为family类型
    currency: 'CNY',
    isDefault: false,
  );
  await service.createLedger(ledger);
}
```

### 2️⃣ API 改动（无需改动）

**现有API完全满足需求，无需修改！**

现有端点:
- `GET /api/v1/ledgers` - 获取所有账本/家庭
- `POST /api/v1/ledgers` - 创建账本/家庭
- `GET /api/v1/ledgers/current` - 获取当前账本/家庭
- `PUT /api/v1/ledgers/:id` - 更新账本/家庭
- `DELETE /api/v1/ledgers/:id` - 删除账本/家庭
- `POST /api/v1/ledgers/:id/share` - 分享账本/邀请成员

### 3️⃣ 后端改动（极小）

#### A. 数据库字段补充
```sql
-- 为ledgers表添加type字段（如果还没有）
ALTER TABLE ledgers 
ADD COLUMN IF NOT EXISTS type VARCHAR(20) DEFAULT 'family';

-- 添加描述字段
ALTER TABLE ledgers 
ADD COLUMN IF NOT EXISTS description TEXT;

-- 添加设置字段
ALTER TABLE ledgers 
ADD COLUMN IF NOT EXISTS settings JSONB;
```

#### B. Rust模型更新
```rust
// handlers/ledgers.rs
#[derive(Debug, Serialize, Deserialize)]
pub struct Ledger {
    pub id: Uuid,
    pub family_id: Option<Uuid>,
    pub name: String,
    #[serde(rename = "type")]
    pub ledger_type: String,  // 已有，确保传递
    pub description: Option<String>,  // 新增
    pub currency: Option<String>,
    pub is_default: Option<bool>,
    pub settings: Option<serde_json::Value>,  // 新增
    pub created_at: Option<DateTime<Utc>>,
    pub updated_at: Option<DateTime<Utc>>,
}
```

### 4️⃣ Provider 层优化

#### A. 添加别名方法（向后兼容）
```dart
// ledger_provider.dart
class CurrentLedgerNotifier extends StateNotifier<Ledger?> {
  // 保留原有方法
  Future<void> switchLedger(Ledger ledger) async { ... }
  
  // 添加别名方法
  Future<void> switchFamily(Ledger family) => switchLedger(family);
}

// 添加别名Provider
final currentFamilyProvider = currentLedgerProvider;
final familiesProvider = ledgersProvider;
```

### 5️⃣ 完整的 UI 组件实现

#### A. 创建家庭对话框
```dart
class CreateFamilyDialog extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.family_restroom, color: Theme.of(context).primaryColor),
          SizedBox(width: 8),
          Text('创建新家庭'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: '家庭名称',
              hintText: '例如：我的家庭',
              prefixIcon: Icon(Icons.home),
            ),
          ),
          SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: 'family',
            decoration: InputDecoration(
              labelText: '类型',
              prefixIcon: Icon(Icons.category),
            ),
            items: [
              DropdownMenuItem(value: 'family', child: Text('家庭账本')),
              DropdownMenuItem(value: 'personal', child: Text('个人账本')),
              DropdownMenuItem(value: 'business', child: Text('商业账本')),
            ],
            onChanged: (value) => setState(() => type = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          child: Text('取消'),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          child: Text('创建'),
          onPressed: _createFamily,
        ),
      ],
    );
  }
}
```

#### B. 家庭切换器组件
```dart
class FamilySwitcher extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentLedgerProvider);
    final allLedgers = ref.watch(ledgersProvider);
    
    return PopupMenuButton<Ledger>(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getLedgerIcon(current?.type ?? 'family'), size: 20),
            SizedBox(width: 8),
            Text(current?.name ?? '选择家庭'),
            Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
      itemBuilder: (context) => [
        ...allLedgers.map((ledger) => PopupMenuItem(
          value: ledger,
          child: ListTile(
            leading: Icon(_getLedgerIcon(ledger.type)),
            title: Text(ledger.name),
            subtitle: Text(_getLedgerTypeLabel(ledger.type)),
            trailing: current?.id == ledger.id 
              ? Icon(Icons.check, color: Colors.green) 
              : null,
          ),
        )),
        PopupMenuDivider(),
        PopupMenuItem(
          child: ListTile(
            leading: Icon(Icons.add, color: Colors.blue),
            title: Text('创建新家庭'),
            subtitle: Text('成为Owner'),
          ),
          onTap: () => _showCreateDialog(context),
        ),
      ],
      onSelected: (ledger) {
        ref.read(currentLedgerProvider.notifier).switchLedger(ledger);
      },
    );
  }
}
```

## 🚀 实施步骤

### 第一阶段：基础改造（1天）
1. ✅ 更新数据库字段
2. ✅ 更新后端模型
3. ✅ 添加Provider别名
4. ✅ 修改UI文本

### 第二阶段：功能完善（1天）
1. ✅ 实现创建家庭对话框
2. ✅ 完善家庭切换器
3. ✅ 实现成员邀请UI
4. ✅ 测试所有功能

### 第三阶段：优化体验（可选）
1. ⏳ 添加家庭头像/图标
2. ⏳ 显示成员数量
3. ⏳ 添加最近访问时间
4. ⏳ 实现家庭设置页面

## 📊 改动统计

| 层级 | 文件数 | 代码行数 | 改动类型 |
|------|--------|----------|----------|
| 前端UI | 2-3个 | ~50行 | 文本替换+小组件 |
| API | 0个 | 0行 | 无需改动 |
| 后端 | 1个 | ~10行 | 字段补充 |
| 数据库 | 1个SQL | ~5行 | 字段补充 |
| **总计** | **4-5个** | **~65行** | **极小改动** |

## ✅ 优势总结

1. **最小化改动**: 总共只需改动约65行代码
2. **零破坏性**: 所有现有功能继续工作
3. **快速实施**: 1-2天完成全部改造
4. **向后兼容**: 新旧API都可使用
5. **用户无感**: 平滑过渡，无需数据迁移

## 🎯 核心结论

**现有Ledger系统已经是一个完整的多租户系统，只需要：**
1. 改变UI显示文本（账本→家庭）
2. 创建时默认type为'family'
3. 根据type显示不同图标

**这是最优方案，因为：**
- 避免重复开发
- 利用现有成熟代码
- 最快速度交付功能
- 最低维护成本