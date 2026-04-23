import Foundation

/// v1.2.1 · PromptBuilder 三维度调制状态载体
/// RFC §2.1–2.3 — 有状态的 instruments / density / energy 调制。
/// 状态持有方（AppState）在 selectStyle 时重置，evolve tick 时按挡位更新。

// MARK: - Instrument Pool (RFC §2.1)

/// 频道乐器池的三层结构。
/// - `core`：奠定频道身份的乐器，**永不进 active，也不移除**（由 style.prompt 自带）
/// - `accent`：1m 挡粒度 ±1，给频道"点色彩"
/// - `optional`：30s 挡粒度 ±1，锦上添花
struct InstrumentPool {
    let core: [String]
    let accent: [String]
    let optional: [String]
}

// MARK: - Density / Energy Phrase Mapping (RFC §2.2, §2.3)

enum EvolveDimension: String, CaseIterable {
    case instruments
    case density
    case energy
}

/// 连续游走的 scalar 映射到四档英文描述词。
/// 区间：[..<0.45] sparse/laid-back · [..<0.65] moderate/steady · [..<0.85] dense/driving · [0.85..] full/intense
enum PromptPhrase {
    static func density(_ v: Float) -> String {
        switch v {
        case ..<0.45: return "sparse arrangement"
        case ..<0.65: return "moderate arrangement"
        case ..<0.85: return "dense arrangement"
        default:      return "full arrangement"
        }
    }

    static func energy(_ v: Float) -> String {
        switch v {
        case ..<0.45: return "laid-back feel"
        case ..<0.65: return "steady groove"
        case ..<0.85: return "driving rhythm"
        default:      return "intense energy"
        }
    }
}

// MARK: - Continuous Walk Helper

/// 带边界反射的连续游走：当前值 ± 随机步长，裁剪到 [min, max]。
/// RFC §2.2 / §2.3 步长 0.15，范围 [0.3, 1.0]。
enum ScalarWalk {
    static let range: ClosedRange<Float> = 0.3...1.0
    static let step: Float = 0.15

    static func next(_ current: Float) -> Float {
        let delta = Float.random(in: -step...step)
        return max(range.lowerBound, min(range.upperBound, current + delta))
    }
}
