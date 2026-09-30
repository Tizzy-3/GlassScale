import SwiftUI
import UIKit

/// App 图标切换器（单例）。
/// 之所以不活在 picker 里：iOS 26 的 LSIconAlertManager 在 modal sheet 弹着时
/// 拿不到 presentation token，setAlternateIconName 会一直报
/// NSPOSIXErrorDomain Code 35 (EAGAIN)「资源暂时不可用」。所以流程是：
/// 点选 → 收起 sheet → 等动画完成 → 从干净的界面调用系统 API。
/// EAGAIN 仍按 0.5s / 1s / 2s / 4s 退避重试（最多 5 次），覆盖新安装后
/// LaunchServices 索引未完成的瞬时情况。
@Observable
final class AppIconSwitcher {
    static let shared = AppIconSwitcher()

    /// 切换失败时的错误信息（SettingsView 监听并弹 alert）
    var errorMessage: String? = nil
    var isSwitching: Bool = false

    private init() {}

    func requestSwitch(to choice: AppIconChoice, store: WeightStore) {
        guard !isSwitching else { return }
        guard UIApplication.shared.supportsAlternateIcons else {
            errorMessage = "当前设备不支持更换 App 图标"
            return
        }
        isSwitching = true
        errorMessage = nil
        // 等 sheet 收起动画完成再调，给 LSIconAlertManager 一个干净的上下文
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.applyWithRetry(choice: choice, store: store, attempt: 0)
        }
    }

    private func applyWithRetry(choice: AppIconChoice, store: WeightStore, attempt: Int) {
        // 成功时系统会自动弹一次确认框
        UIApplication.shared.setAlternateIconName(choice.iconName) { error in
            if let nsError = error as NSError?,
               nsError.domain == NSPOSIXErrorDomain,
               nsError.code == 35,  // EAGAIN：稍后再试
               attempt < 4 {
                let backoff: [Double] = [0.5, 1.0, 2.0, 4.0]
                DispatchQueue.main.asyncAfter(deadline: .now() + backoff[attempt]) {
                    self.applyWithRetry(choice: choice, store: store, attempt: attempt + 1)
                }
                return
            }
            DispatchQueue.main.async {
                self.isSwitching = false
                if let error {
                    let nsError = error as NSError
                    self.errorMessage = "\(error.localizedDescription)（\(nsError.domain) \(nsError.code)，已重试 \(attempt) 次）"
                } else {
                    var s = store.settings
                    s.appIcon = choice
                    store.updateSettings(s)
                }
            }
        }
    }
}
