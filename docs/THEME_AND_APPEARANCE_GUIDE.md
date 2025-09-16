# Jive 主题与外观设计指南（v1）

本指南用于规范全局主题（Theme）、外观参数（密度、圆角、配色）、深浅色模式与护眼主题，并给出列表类页面的“即插即用”适配规范。面向未来尚未设计的列表/设置/明细页面，照章即可快速落地一致的观感与交互。

## 1. 设计目标
- 一致：全局配色、间距、圆角与控件状态一致，跨页面风格统一。
- 可切换：支持浅色/深色/护眼主题与用户自定义配色；支持列表密度（舒适/紧凑）、圆角（小/中/大）。
- 可读：保证文本对比度与信息层级清晰；支持不同屏幕尺寸自适配。
- 可扩展：主题通过“设计令牌”（Design Tokens）和 ThemeData 映射，后续页面零侵入接入。

---

## 2. 设计令牌（Design Tokens）

下述语义令牌与 Flutter `ThemeData / ColorScheme` 和项目自定义 `CustomThemeData` 字段一一映射。

### 2.1 颜色（Color Tokens）
- 语义主色：`primaryColor`（主动作、强调）
- 次要色：`secondary`（次动作、标签、徽章）
- 背景：`background`（页面背景）、`surface`（容器/卡片背景）、`surfaceVariant`（分组/条纹）
- 文本：`onPrimary`、`onSecondary`、`onBackground`、`onSurface`
- 状态：`success`、`warning`、`error`、`info`
- 边框与分隔：`borderColor`、`dividerColor`
- 导航：`navigationBar`、`navigationBarText`、`navigationBarSelected`

在 Flutter 中对应 `Theme.of(context).colorScheme.*` 与自定义字段；深色模式使用相同语义但替换为暗色值。

### 2.2 外观参数
- 列表密度（List Density）：`comfortable | compact`
  - 全局通过 `VisualDensity`、`ListTileTheme.dense` 与组件内部 padding 细化。
- 圆角（Corner Radius）：`small=8 | medium=12 | large=16`
  - 影响 Card、Sheet、Dialog、TextField 边角，统一从 Theme 扩散。

### 2.3 排版（Typography）
- 标题：16–18（页面/分组标题）、列表主标题 16
- 正文：13–14（副标题/说明 12–13）
- 紧凑模式下字号降低 1 级（例如 14→13，13→12），保持可读性优先。

### 2.4 间距（Spacing）
- 采用 4/8 尺度：`4, 8, 12, 16, 20, 24`
- 舒适：卡片外边距 16/6、列表项内边距 12×8
- 紧凑：卡片外边距 12/4、列表项内边距 10×6

### 2.5 阴影与分层
- Card 默认 `elevation=1–2`；深色模式降低阴影并提高分隔线对比。

---

## 3. 模式与主题

### 3.1 模式
- 浅色模式：高对比但不过曝；背景以白/浅灰为主。
- 深色模式：背景 `#0F1419 ~ #1C242C` 阶梯；文本对比不低于 WCAG AA。
- 护眼主题：低饱和、低对比、柔和背景（蓝灰/青绿/夜间），减少大面积纯白/纯黑。

### 3.2 预设与自定义
- 预设主题：经典蓝、暖橙、清新绿、优雅紫、深邃蓝、活力红、自然棕、科技青、护眼（蓝灰/青绿/夜间）。
- 自定义主题：以 `CustomThemeData` 序列化存储，支持分享/导入。

---

## 4. 组件适配规范（列表类页面）

以下规范适用于所有列表类页面（账户、分类、交易、价格、设置项等）。

### 4.1 列表项（List Item）
- 结构：Leading（图标/标识） + 主标题 + 次标题/元信息 + Trailing（操作/指示）
- 高度：
  - 舒适：行高建议 64 左右（含 48 图标与上下 padding）
  - 紧凑：行高建议 56 左右（含 40 图标与更小 padding）
- 文字：
  - 主标题 16 加粗；次标题 12–13、`onSurfaceVariant` 颜色
  - 溢出优先 `TextOverflow.ellipsis`
- 间距：主标题与次标题之间 4–6；徽章与文本之间 6–8
- 辅助徽章：用 `SourceBadge/Chip` 表示来源、状态、标记；颜色取自 `primary/secondary/tertiary/outline`

### 4.2 卡片（Card）
- 背景：`colorScheme.surface`
- 外边距：舒适 16/6；紧凑 12/4
- 圆角：跟随主题 `cornerRadius`
- 阴影：普通场景 1–2；展开/选中可加至 2

### 4.3 搜索与筛选
- 搜索栏背景使用 `surface`；前景 `onSurface`
- 输入框圆角/边线从 `inputDecorationTheme` 继承；密度影响 contentPadding（舒适 12×8，紧凑 10×6）

### 4.4 分组与页脚
- 分组标题行：`surfaceVariant` 背景 + 12–16 内边距 + 12 字号描述
- 页脚信息：使用 `onSurfaceVariant` 颜色；提供“帮助/说明”按钮（如“来源说明”）
- 安全区域：列表底部预留 `SafeArea(bottom:true)` + 额外 64–88 padding 避免覆盖

### 4.5 选择与多选
- 勾选：`Checkbox` 使用 `activeColor=primary`；密度紧凑时 `visualDensity` 提升（-2,-2）
- 基础项突出：可用 `tertiaryContainer` 背景或细边框强调“基础/重要”项

### 4.6 展开内容（Expansion）
- 展开区整体使用 Card 内边距（舒适 16、紧凑 12）
- 表单控件：`TextField` contentPadding 随密度变化（舒适 12×8、紧凑 10×6）
- 操作按钮：`TextButton.icon` 前景色取主语义色（例如 primary/secondary）

### 4.7 状态与占位
- 加载：优先骨架屏或小型 `CircularProgressIndicator`（strokeWidth 2）
- 空态：图标 + 一行提示 + 次要行说明；按钮颜色使用 `primary`
- 错误：文案使用 `error` 语义色；可附“重试”操作

---

## 5. 数据与来源展示规范

### 5.1 汇率/价格来源
- 每个目标币种显示来源徽章（ExchangeRate-API / ECB / FXRates / CoinGecko / 手动 等）
- 合并回退：优先使用主源，缺失由后备补齐；徽章以实际来源为准
- 页脚：显示“上次更新时间 + 来源链 + 缓存 TTL”，并提供“来源说明”弹窗

### 5.2 缓存与刷新
- 法币缓存：15 分钟；加密缓存：5 分钟
- 刷新按钮：工具栏右侧；刷新中替换为 `CircularProgressIndicator`

---

## 6. 可访问性与国际化

- 对比度：正文对比度尽量 ≥ 4.5:1；按钮/链接 ≥ 3:1
- 动效：遵循“减少动态效果”系统设置；过渡 120–200ms、Easing 使用标准 Material 曲线
- 文案：中/英双语可切换；遵守本地化格式（数字、货币、日期）
- 版式：保证小屏（≤360dp）无溢出；横竖屏支持；优先流式排版

---

## 7. 实现对接（Flutter）

### 7.1 全局注入
- `ThemeData`：在 `ThemeService` 生成；`AppThemeSettings` 负责主题模式、预设/自定义主题选择
- 外观：`settingsProvider` 持久化 `listDensity`、`cornerRadius`
- App 根：在 `app.dart`/`core/app.dart` 中将 `visualDensity`、`cardTheme`、`inputDecorationTheme` 等根据 `settingsProvider` 合并覆盖

### 7.2 列表页面示例（伪代码）
```
final isCompact = ref.watch(settingsProvider).listDensity == 'compact';
return ListView.builder(
  padding: EdgeInsets.only(top: 8, bottom: footer ? 88 : 8),
  itemBuilder: (_, i) => Card(
    margin: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 16, vertical: isCompact ? 2 : 4),
    child: ListTile(
      dense: isCompact,
      leading: SizedBox(width: isCompact ? 40 : 48, height: isCompact ? 40 : 48, child: ...),
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: isCompact ? 12 : 13, color: Theme.of(context).colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
      trailing: Checkbox(visualDensity: isCompact ? const VisualDensity(horizontal: -2, vertical: -2) : null, ...),
    ),
  ),
);
```

### 7.3 主题扩展点
- SourceBadge：颜色从 `ColorScheme` 拿（primary/secondary/tertiary/outline）
- 页脚：`onSurfaceVariant` 文案 + `TextButton.icon` 触发说明弹窗
- 搜索栏：`surface` 背景 + `OutlineInputBorder` 圆角跟随全局设置

---

## 8. 验收清单（开发自测）
- [ ] 浅/深色模式切换正常，文本可读、无对比不足
- [ ] 舒适/紧凑密度切换，列表行高、字号、间距同步变化
- [ ] 圆角三档在 Card、Dialog、输入框等处一致生效
- [ ] 小屏（≤360dp）无“Bottom overflowed”类溢出；底部 `SafeArea` 生效
- [ ] 列表项标题 16、次标题 12–13，溢出省略
- [ ] 刷新状态/错误状态/空态表现完整
- [ ] 来源徽章与页脚信息符合“来源与缓存”规范

---

## 9. 后续演进建议
- 自动对比度检测与文字颜色自适应（AA/AAA）
- 动画统一曲线/时长配置，适配系统“减少动画”
- 列表虚拟化/懒加载规范（大量数据性能）
- 图表配色与可达性（色盲安全色板）
- 深色模式下的阴影与分隔优化规范

---

## 10. 附录：字段/实现映射

- Settings（SharedPreferences）
  - `listDensity: comfortable|compact`
  - `cornerRadius: small|medium|large`
  - `themeMode: system|light|dark`（如在 ThemeService 中管理）
- CustomThemeData 字段：参考 `jive-flutter/lib/models/theme_models.dart`
- 主题服务：`jive-flutter/lib/services/theme_service.dart`
- 密度/圆角注入：`jive-flutter/lib/core/app.dart`（`visualDensity`、`cardTheme`、`inputDecorationTheme`）
- 来源徽章：`jive-flutter/lib/widgets/source_badge.dart`

> 采用本指南开发的新页面，只需遵循“设计令牌 + 列表适配规范 + 可访问性”三要点，即可保持与当前页面一致的视觉与交互体验。

