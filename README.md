# 享瘦 GlassScale

一个 **iOS 26 液态玻璃（Liquid Glass）** 风格的体重管理记录 App。
纯本地、零第三方依赖、无账号、无网络请求。

> 目标系统 **iOS 26.0+**，需要 **Xcode 26.0+** 编译。
> 代码已写好，**本仓库不做编译与签名**，你直接在 Xcode 里改 Bundle ID 和 Team 后跑即可。

---

## 一分钟上手

```bash
open "GlassScale.xcodeproj"
```

在 Xcode 里：

1. 选中 **GlassScale** target → **Signing & Capabilities**
2. 勾上 **Automatically manage signing**，选你的 Team
3. 把 **Bundle Identifier** 改成你自己的（默认 `com.example.glassscale`）
4. 选真机 + ⌘R

**工程用的是 Xcode 16+ 的「文件夹同步」组**（`PBXFileSystemSynchronizedRootGroup`），
你在 `GlassScale/` 目录里新建 `.swift` 文件会被自动纳入编译，不需要手动改 pbxproj。

---

## 目录结构

```
ios app/
├── GlassScale.xcodeproj/          # 工程文件（手写 pbxproj，objectVersion 77）
├── GlassScale.entitlements        # HealthKit 权限文件（默认未启用，见下文）
└── GlassScale/                    # 同步组：这个目录下的文件全部参与编译
    ├── App/
    │   ├── GlassScaleApp.swift    # @main 入口
    │   └── RootView.swift         # TabView + 底部快捷条 + 里程碑浮层
    ├── Core/
    │   ├── Model/                 # 纯数据与纯计算，不依赖 UI
    │   │   ├── WeightEntry.swift
    │   │   ├── WeightGoal.swift
    │   │   ├── BodyProfile.swift
    │   │   ├── AppSettings.swift  # 单位枚举 + 格式化
    │   │   └── WeightStats.swift  # 统计引擎（7日均/回归/连续天数/BMI）
    │   └── Store/
    │       ├── WeightStore.swift  # 唯一数据源（@Observable）
    │       ├── Persistence.swift  # JSON 落盘
    │       └── HealthKitManager.swift
    ├── Design/
    │   ├── Theme.swift            # 配色、圆角、渐变
    │   ├── AuroraBackground.swift # 极光背景（玻璃的折射源）
    │   └── GlassComponents.swift  # GlassCard / StatTile / GlassSegmented …
    ├── Features/
    │   ├── Dashboard/             # 首页 + 进度环 + 快捷条 + 庆祝浮层
    │   ├── History/               # 记录列表 + 编辑器
    │   ├── Trends/                # 趋势图 + 每日涨跌
    │   ├── Goals/                 # 目标编辑
    │   ├── Onboarding/            # 首次引导
    │   └── Settings/              # 设置 + 导出
    └── Resources/Assets.xcassets  # 图标与强调色
```

---

## 功能清单

| 模块 | 内容 |
|---|---|
| **首页** | 当前体重、目标进度环（百分比动画）、近 7 日均、本周变化、距目标、BMI 分级、30 天趋势图、最近 3 条记录、可展开的玻璃 FAB |
| **底部快捷条** | 常驻玻璃条，显示今天体重，± 一步微调，一点「记一笔」直接保存 |
| **记录** | 按月分组、每月净变化、每行相对上一条的变化、搜索备注/体重、左滑删除、点开编辑 |
| **趋势** | 1 月 / 3 月 / 6 月 / 1 年 / 全部切换，主折线 + 7 日均线 + 目标虚线、按住可查看任意一天读数、每日涨跌柱状图、区间净变化 / 拟合速度 / 均重 / 极值 |
| **目标** | 目标体重、目标日期、按当前趋势自动预测「其实哪天能到」 |
| **里程碑** | 每跨过 5 kg 整数档、或达成目标时弹出玻璃庆祝浮层（不会重复弹同一步） |
| **健康** | 读取/写入 Apple 健康体重，导入去重，同一天以「健康」中最晚一条为准 |
| **数据** | 导出 CSV（Excel 可开）/ 完整 JSON 备份、载入 90 天示例数据、一键清空 |
| **单位** | 公斤 / 市斤 / 磅，厘米 / 英寸，随时切换；**数据层永远存千克**，切单位不会污染历史 |
| **档案** | 身高、年龄、性别、起始体重（用于算完成度） |

---

## 液态玻璃是怎么用的

遵循 Apple 的设计原则：**玻璃只放在浮在内容之上的导航 / 操作层**，
普通列表行用清透背景而不是玻璃（省电、层次也更清楚）。
玻璃要有东西可折射才好看，所以整个 App 底层是一层缓慢流动的极光渐变。

用到的官方 API：

- `.glassEffect(_:in:)` — 卡片、磁贴、芯片、提示条
- `GlassEffectContainer(spacing:)` — 磁贴网格、± 按钮、引导页分段控件
- `Glass.regular / .clear`、`.tint(_:)` — 主行动用薄荷色描色
- `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)` — 所有按钮
- `.glassEffectID(_:in:)` + `@Namespace` — 首页 FAB 展开时玻璃互相形变
- `TabView` + `Tab(_:systemImage:value:)` — 自动获得液态玻璃标签栏
- `.tabBarMinimizeBehavior(.onScrollDown)` — 下滚时标签栏收起
- `.tabViewBottomAccessory` — 底部常驻快捷条
- `ToolbarItem` — 导航栏自动玻璃化

**如果你要改成本地化/其它语言**：目前界面文案是简体中文硬编码的。
`AppSettings` 里已有单位枚举的完整中英映射，扩展成多语言时建议把字符串抽到
`zh-Hans.lproj/Localizable.strings` + `Base.lproj/`，再在根视图挂
`.environment(\.locale, ...)`。

---

## HealthKit 怎么启用

**默认不启用**，这样你用免费 Apple ID 个人证书也能直接装、直接跑。

代码里的 HealthKit 调用全部做了容错：没有授权时「健康」那一栏显示「未连接 / 本机不可用」，
其余功能完全不受影响。

如果你有**付费开发者账号**，想启用：

1. Target → **Signing & Capabilities** → **+ Capability** → 勾选 **HealthKit**
   （Xcode 会自动生成/关联 entitlements）
2. 或者手动把仓库根目录的 `GlassScale.entitlements` 填到
   **Build Settings → Code Signing Entitlements**（值填 `GlassScale.entitlements`）
3. 重新编译安装，首次进入「我的 → Apple 健康 → 连接「健康」」时弹系统授权

> 免费个人开发证书（Personal Team）**不支持 HealthKit capability**，
> 强行加 entitlement 会导致安装失败。所以默认不给 target 挂 entitlements。

模拟器没有真实健康数据，导入会拿到空数组（App 会提示「没有新的体重数据」），属于正常。

---

## 架构要点

- **单一数据源**：`@Observable final class WeightStore`。改动 → 统计 → 防抖 0.35s 落盘。
- **统计是纯函数**：`StatsEngine.compute(entries:profile:)` 不持有状态，
  `TrendView` 还能对任意区间单独算一份，不污染全局。
- **存储永远千克**，只在 `Fmt` / `WeightUnit.value(forKg:)` 这一层换算。
- **图表零依赖**：Swift Charts 直接用 `AreaMark + LineMark + RuleMark`，支持按住查看读数。
- **持久化**：`Application Support/GlassScale/store.json`（原子写，App Support 不参与 iCloud 同步备份）。

### 想改成 Unit Test / 预览

`WeightStore(preview: true)` 会跳过读盘，可以直接灌示例数据做预览。
新建一个 `Preview.swift` 丢进 `GlassScale/Preview/`（同步组会自动编译）：

```swift
import SwiftUI

#Preview("首页") {
    let store = WeightStore(preview: true)
    store.loadSampleData()
    store.settings.hasCompletedOnboarding = true
    return RootView().environment(store)
}

#Preview("空状态") {
    let store = WeightStore(preview: true)
    store.settings.hasCompletedOnboarding = true
    return RootView().environment(store)
}
```

统计逻辑是纯函数，也可以脱离 UI 直接测：

```swift
let entries = SampleData.make(count: 60)
let stats = StatsEngine.compute(entries: entries, profile: BodyProfile(heightCm: 172))
print(stats.average7Kg as Any, stats.weeklyRateKg as Any, stats.streakDays)
```

---

## 已知取舍

1. **界面只做了简体中文**。单位做了中英两套，但文案没做多语言（见上文「怎么改成多语言」）。
2. **没有做本地提醒通知**（每日称重提醒）。如果你要加，在
   `RootView` 的 `.onChange(of: scenePhase)` 里用 `UNUserNotificationCenter` 注册一个
   `UNCalendarNotificationTrigger` 即可，逻辑约 30 行。
3. **HealthKit 只做手动导入 / 主动写入**，没有 `HKObserverQuery` 后台同步。
   想要「Apple Watch 量完自动出现」需要在 `HealthKitManager` 里加 observer query +
   `enableBackgroundDelivery`，并声明 `UIBackgroundModes`。
4. **进度环的「起点」**默认取引导页填的起始体重，没有就取最早一条记录，
   可以在「我的 → 身体档案」里手动改。

---

## 图标

`Assets.xcassets/AppIcon.appiconset` 里已经放好 1024×1024 的浅色 / 深色两版图标
（脚本生成：极光渐变底 + 玻璃卡片 + 下行趋势线）。
想换直接把 1024×1024 PNG 覆盖进去即可，记得保持文件名或同步改 `Contents.json`。
