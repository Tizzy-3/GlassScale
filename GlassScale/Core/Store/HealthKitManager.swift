import Foundation
import HealthKit
import Observation

/// 「健康」App 的体重读写。
///
/// 设计上刻意只用最经典、最稳定的 HealthKit API（completion handler + continuation），
/// 这样在不同 Xcode 26 小版本上都能编译通过。
///
/// 注意：HealthKit 是 **可选能力**。
/// 如果你的签名没有勾选 HealthKit（免费 Apple ID 个人证书就不支持），
/// 这里的所有调用都会失败，App 依然可以正常记录，只是「健康」那一栏显示为未连接。
@Observable
final class HealthKitManager {

    enum Status: Equatable {
        case unsupported      // 模拟器 / 设备不支持
        case notDetermined
        case authorized       // 允许写入
        case denied
        case failed(String)

        var isConnected: Bool { self == .authorized }
    }

    private(set) var status: Status = .notDetermined

    private let store = HKHealthStore()
    private var bodyMassType: HKQuantityType? { HKQuantityType(.bodyMass) }

    init() {
        refreshStatus()
    }

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// 同步读取“是否允许写入”。注意：iOS 出于隐私不会告诉 App 用户是否允许读取，
    /// 所以只读权限只能通过实际拉取是否成功来判断。
    func refreshStatus() {
        guard Self.isAvailable, let type = bodyMassType else {
            status = .unsupported
            return
        }
        switch store.authorizationStatus(for: type) {
        case .notDetermined: status = .notDetermined
        case .sharingAuthorized: status = .authorized
        case .sharingDenied: status = .denied
        @unknown default: status = .notDetermined
        }
    }

    /// 弹出系统的健康授权面板。
    func requestAuthorization() async {
        guard Self.isAvailable, let type = bodyMassType else {
            status = .unsupported
            return
        }
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                store.requestAuthorization(toShare: [type], read: [type]) { success, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if success {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: HKError(.errorAuthorizationDenied))
                    }
                }
            }
            refreshStatus()
        } catch {
            status = Self.isAvailable ? .failed(error.localizedDescription) : .unsupported
        }
    }

    /// 写入一条体重。
    func save(weightKg: Double, at date: Date) async throws {
        guard Self.isAvailable, let type = bodyMassType else {
            throw HKError(.errorHealthDataUnavailable)
        }
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weightKg)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.save(sample) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HKError(.errorHealthDataUnavailable))
                }
            }
        }
    }

    /// 从「健康」拉取体重样本，返回按时间升序排列。
    func fetchBodyMass(since startDate: Date?) async throws -> [HKQuantitySample] {
        guard Self.isAvailable, let type = bodyMassType else {
            throw HKError(.errorHealthDataUnavailable)
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: nil,
            options: .strictStartDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKQuantitySample], Error>) in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
                }
            }
            store.execute(query)
        }
    }

    /// 删除本 App 写入的一条体重。
    func delete(weightKg: Double, at date: Date) async throws {
        guard Self.isAvailable, let type = bodyMassType else {
            throw HKError(.errorHealthDataUnavailable)
        }
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weightKg)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.delete(sample) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HKError(.errorHealthDataUnavailable))
                }
            }
        }
    }
}
