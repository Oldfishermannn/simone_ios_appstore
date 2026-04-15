# Simone iOS — 三层页面 UI 重构设计

## Context

当前 Simone iOS 只有展开/折叠两种状态，所有功能挤在一个 ScrollView 里。用户希望将 UI 重构为三层垂直滑动页面：沉浸模式、主页、Details 页，提供更清晰的层次和更好的使用体验。

**核心原则：频谱可视化及其交互完全不动。**

---

## 页面结构

### 1. 沉浸模式（主页上滑进入）

- 频谱全屏显示，无任何 UI 元素
- 保留左右滑动切换可视化器 + 小圆点（与当前折叠态一致）
- 下滑返回主页

### 2. 主页（默认页面）

- 频谱轮播（保持现有设计不变：左右滑动 + 圆点指示器）
- 当前风格名
- 播放控制（⏮ ▶ ⏭）放在页面底部
- 上滑进入沉浸模式，下滑进入 Details

### 3. Details 页（主页下滑进入）

从上到下依次排列：

**迷你播放器**（顶部）
- 小频谱缩略 + 当前风格名 + 播放状态 + 暂停按钮

**喜爱歌单**
- 列表样式，每行：🎵 图标 + 风格名 + ♥/♡ 按钮
- 点击 ♥ 添加到喜爱 / 点击 ♥ 移除
- 左滑删除
- 顶部有 🔁 顺序 / 🔀 随机 循环切换
- 点击风格名直接播放

**推荐风格**
- 列表样式，每行：✨ 图标 + 风格名 + ♡ 按钮
- 点击 ♡ 加入喜爱列表
- 顶部有「↻ 换一批」按钮，点击生成全新的随机风格（不是从已有列表中取）
- 点击风格名直接播放

**Evolve 演化**
- 四档按钮：锁定 / 10s / 1min / 5min（保持现有逻辑不变）

**定时关闭**（新增）
- 四档按钮：15分 / 30分 / 1小时 / 2小时
- 选中后开始倒计时，时间到自动暂停播放并断开 WebSocket

---

## 交互方式

- 三层页面通过上下滑动切换，使用 SwiftUI `TabView` 的 `.page` 样式（垂直方向）或自定义垂直分页
- 频谱区域的左右滑动（切换可视化器）与页面的上下滑动不冲突
- 沉浸模式下隐藏状态栏

---

## 数据模型变更

### 新增

- `playbackMode: PlaybackMode`（顺序 `.sequential` / 随机 `.shuffle`）
- `sleepTimer: SleepTimer?`（倒计时状态 + 目标时间）
- `sleepTimerRemaining: TimeInterval`（剩余时间）

### 保留不变

- `pinnedStyles` → 重命名为概念上的"喜爱"，底层数据结构不变
- `exploredStyles` → 推荐列表数据源
- `evolveMode` → 不变
- 所有 Lyria 参数 → 不变

---

## 文件变更

### 新建
- `Views/ImmersiveView.swift` — 沉浸模式页面
- `Views/DetailsView.swift` — Details 页面（歌单 + 控制）
- `Views/MiniPlayerView.swift` — 迷你播放器组件
- `Views/StyleRowView.swift` — 风格列表行组件（喜爱/推荐复用）

### 修改
- `Views/ContentView.swift` — 改为三层垂直分页容器
- `Views/PlayControlView.swift` — 位置下移到底部（组件本身不变）
- `Models/AppState.swift` — 新增 playbackMode、sleepTimer、换一批逻辑

### 不动
- `Views/SpectrumCarouselView.swift` — 完全不动
- `Views/Visualizers/*` — 所有 8 个可视化器完全不动
- `Audio/*` — 不动
- `Network/*` — 不动
- `Models/MusicStyle.swift` — 不动
- `Models/VisualizerStyle.swift` — 不动

### 删除
- `Views/ExpandableCardView.swift` — 功能拆分到 DetailsView，不再需要

---

## 验证方式

1. 编译运行，确认三层页面上下滑动正常
2. 确认频谱轮播（左右滑动 + 圆点）在三个页面都正常工作
3. 在 Details 页测试：点击风格播放、♥ 收藏/取消、左滑删除、换一批
4. 测试顺序/随机循环播放
5. 测试定时关闭：选 15 分钟，确认倒计时结束后自动暂停
6. 测试沉浸模式：确认全屏无 UI，下滑可返回
7. 确认锁屏 Now Playing 控制仍然正常
