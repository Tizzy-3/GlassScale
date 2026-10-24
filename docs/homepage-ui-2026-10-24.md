# 首页 UI 优化验收

本轮完成首页及必要的公共样式，沿用 SwiftUI、Swift Charts 和 iOS 26 原生 TabView。分支为 `ui/floating-glass-preview`，未合并 main。

## 实现范围

- 统一规范见 [MASTER](../design-system/glassscale/MASTER.md) 和 [首页规范](../design-system/glassscale/pages/dashboard.md)：五套主题的明暗颜色、系统字体、间距、圆角、阴影、按钮状态与动效。
- 首页采用浅冰蓝体重区、薄荷喝水区、只读的七日记录概览、统一的最近记录及详细指标卡片。保留日历补录、目标设置、记体重、喝水历史/补录、杯量设置、自定义喝水量和撤销入口。
- 原创 SwiftUI 矢量水杯按现有进度显示水位与达标表情；成功记录后短暂反馈。自定义动效读取系统减少动态效果设置。
- 大字体下改为纵向阅读，数值/单位可自动换行，独立图标保持 20pt、操作区域至少 44pt，主按钮至少 48pt。
- 首页图表明确区分蓝色体重实线、绿色七日均值虚线和目标线；只调整图形分组、颜色与标注，统计数据及计算公式未改。共享图表的其他调用仍使用旧样式。
- 未改 Core、数据结构、存储、接口、HealthKit 或提醒逻辑；原有 WaterGoalSheet 保持原文。未引入 UI 框架或外部运行时依赖。

主要文件：`Design/AppDesign.swift`、`Design/WaterCupView.swift`、三个 `Features/Dashboard` 视图，以及共享 `Features/Trends/WeightChartView.swift` 的首页样式选项。另有仅 DEBUG 模拟器可用的截图数据/滚动定位与截图脚本。

## 已验证

应用提交：`1ea241aa3cef6dbec613cf02d080ca714df5d5a9`。后续验收文档提交不改变应用代码。

[最终构建 Run52](https://github.com/Tizzy-3/GlassScale/actions/runs/40061351128)：

- 原有回归流程：Asia/Shanghai 110 项、America/Los_Angeles 110 项，均 0 失败。
- iOS Release 设备构建和 Debug 模拟器构建成功。
- 十张最终截图完整生成；日志以 `Screenshots captured` 结束，没有截图步骤错误。已逐张查看，未把启动白屏当作成功截图。
- 74 组语义文字/操作颜色对比度最低 4.56:1；十组主按钮按下态对比度最低 5.27:1。
- Release 二进制不含 `--ui-preview` 演示数据入口。

| 设备/场景 | 已检查内容 |
|---|---|
| iPhone 17 Pro，浅/深色 | 首页完整首屏，水杯、文字、快捷操作及原生底栏 |
| 同设备，页面底部，浅/深色 | 最近记录、图表线型/颜色、目标标注、折叠指标与底栏间距 |
| 同设备，最大辅助字号 | 顶部图标、纵向体重阅读、喝水标题与快捷按钮重排 |
| iPhone SE 3，375pt，浅/深色，lb | 窄屏布局、三位数体重及单位 |
| 同小屏，底部和标准 xxxLarge 字号 | 图表标注、详细指标入口、大字号三列统计 |

另在 [Run49](https://github.com/Tizzy-3/GlassScale/actions/runs/40058922488) 检查了空数据、喝水达标表情和落日主题。修改前参考为 Run48 的实际界面，应用提交 `566cbd92539619981719d0824e558db504332c0f`。

截图检查期间修复了最大字号图标超出按钮背景、统计值和单位挤压，以及体重/均值线合并显示的问题。截图脚本增加冷启动等待和重试，旧的白屏截图未计入最终验收。

## 交付文件

- [最终原始截图](https://github.com/Tizzy-3/GlassScale/actions/runs/40061351128/artifacts/12547637144)
- [未签名 IPA](https://github.com/Tizzy-3/GlassScale/actions/runs/40061351128/artifacts/12547471745)
- 本机副本位于项目旁 `ui-preview/run-52/`。
- IPA SHA256：`30ee4acf6d81bc162cc85df78022d6b4a2cf1e4ef75001802e5376f64c904858`。

## 尚未验证

截图能证明上述布局与状态显示，不能证明真机动画帧率、触感或完整 VoiceOver 操作。减少动态效果已做代码核对，尚未在真机切换设置测试。iPad 和横屏未做实际运行检查；项目原有 iPhone 配置只支持竖屏，本轮未改变方向支持。IPA 需要签名后安装。

本轮停在首页，其他页面尚未迁移新设计系统。
