import Foundation
import Combine

enum LLMProvider: String, Codable, CaseIterable, Identifiable {
    case siliconflow = "硅基流动"
    case deepseek    = "DeepSeek"
    case qwen        = "通义千问"
    case kimi        = "Kimi"
    case custom      = "自定义"

    var id: String { rawValue }

    var defaultBaseURL: String {
        switch self {
        case .siliconflow: return "https://api.siliconflow.cn/v1"
        case .deepseek:    return "https://api.deepseek.com/v1"
        case .qwen:        return "https://dashscope.aliyuncs.com/compatible-mode/v1"
        case .kimi:        return "https://api.moonshot.cn/v1"
        case .custom:      return ""
        }
    }

    var defaultModel: String {
        switch self {
        case .siliconflow: return "deepseek-ai/DeepSeek-V3"
        // deepseek-chat/deepseek-reasoner 于 2026-07-24 弃用，映射到 deepseek-v4-flash。
        // 直接默认新 id；想要更强可手填 deepseek-v4-pro。
        case .deepseek:    return "deepseek-v4-flash"
        case .qwen:        return "qwen-turbo"
        case .kimi:        return "moonshot-v1-8k"
        case .custom:      return ""
        }
    }

    /// 该服务商是否支持「从 /v1/models 在线拉取模型清单」。
    /// 硅基流动是聚合平台，模型多且常变，最适合在线拉。
    var supportsModelCatalog: Bool {
        switch self {
        case .siliconflow, .custom: return true
        default: return false
        }
    }

    /// 未联网刷新时的兜底模型清单（仅聚合类服务商需要）。
    var fallbackModels: [String] {
        switch self {
        case .siliconflow: return ModelCatalog.siliconflowFallback
        default: return []
        }
    }
}

enum EnglishAccent: String, Codable, CaseIterable, Identifiable {
    case american = "美式 (American)"
    case british  = "英式 (British)"
    var id: String { rawValue }

    var langCode: String {
        switch self {
        case .american: return "en-US"
        case .british:  return "en-GB"
        }
    }
}

/// 浮标的框选细节：框选即出圆点 / 还是要按住 Option 框选才出。
enum TriggerMode: String, Codable, CaseIterable, Identifiable {
    case selection         = "框选即触发"
    case modifierSelection = "按 Option 时框选才触发"
    var id: String { rawValue }
}

/// 顶层交互方式：选中文字后怎么唤出翻译。
/// - hotkey: 选中后按全局快捷键，直接弹翻译框（无小圆点）。
/// - bubble: 框选后选区旁出小圆点，点圆点才翻译。
/// - both:   两者都开，按各自习惯用。
enum InteractionMode: String, Codable, CaseIterable, Identifiable {
    case hotkey = "快捷键弹翻译框"
    case bubble = "浮标小圆点"
    case both   = "两者都开"
    var id: String { rawValue }

    var hotkeyEnabled: Bool { self == .hotkey || self == .both }
    var bubbleEnabled: Bool { self == .bubble || self == .both }
}

struct ResolvedSettings: Sendable {
    let apiKey: String
    let baseURL: String
    let model: String
    let targetLanguage: String
}

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    private let d = UserDefaults.standard

    @Published var provider: LLMProvider          { didSet { d.set(provider.rawValue,  forKey: K.provider) } }
    /// API Key —— 不再写进 UserDefaults，didSet 落到 Keychain（按 provider 分账存）。
    @Published var apiKey: String                 { didSet { Keychain.write(apiKey, account: provider.rawValue) } }
    @Published var baseURL: String                { didSet { d.set(baseURL,            forKey: K.baseURL) } }
    @Published var model: String                  { didSet { d.set(model,              forKey: K.model) } }
    @Published var targetLanguage: String         { didSet { d.set(targetLanguage,     forKey: K.targetLang) } }
    @Published var triggerMode: TriggerMode       { didSet { d.set(triggerMode.rawValue, forKey: K.trigger) } }
    @Published var interactionMode: InteractionMode { didSet { d.set(interactionMode.rawValue, forKey: K.interaction) } }
    @Published var useClipboardFallback: Bool     { didSet { d.set(useClipboardFallback, forKey: K.clip) } }
    @Published var speechRate: Double             { didSet { d.set(speechRate,         forKey: K.rate) } }
    @Published var englishAccent: EnglishAccent   { didSet { d.set(englishAccent.rawValue, forKey: K.accent) } }
    @Published var enabled: Bool                  { didSet { d.set(enabled,            forKey: K.enabled) } }

    /// 硅基流动「刷新模型列表」拉到的在线模型，缓存在内存供下拉用（不持久化，每次刷新即可）。
    @Published var fetchedModels: [String] = []

    private enum K {
        static let provider = "provider"
        static let apiKey = "apiKey"          // 旧明文键，仅用于一次性迁移
        static let baseURL = "baseURL"
        static let model = "model"
        static let targetLang = "targetLanguage"
        static let trigger = "triggerMode"
        static let interaction = "interactionMode"
        static let clip = "useClipboardFallback"
        static let rate = "speechRate"
        static let accent = "englishAccent"
        static let enabled = "enabled"
        static let keyMigrated = "apiKeyMigratedToKeychain"
        static let dsModelMigrated = "deepseekModelMigratedV4"
    }

    private init() {
        let ud = UserDefaults.standard
        let p = LLMProvider(rawValue: ud.string(forKey: K.provider) ?? "") ?? .siliconflow
        self.provider             = p

        // 一次性迁移：把旧版存在 UserDefaults 明文里的 key 搬进 Keychain，然后抹掉明文。
        if !ud.bool(forKey: K.keyMigrated), let legacy = ud.string(forKey: K.apiKey), !legacy.isEmpty {
            Keychain.write(legacy, account: p.rawValue)
            ud.removeObject(forKey: K.apiKey)
            ud.set(true, forKey: K.keyMigrated)
        }
        // 从 Keychain 读当前 provider 的 key
        self.apiKey               = Keychain.read(account: p.rawValue) ?? ""

        self.baseURL              = ud.string(forKey: K.baseURL) ?? p.defaultBaseURL
        self.model                = ud.string(forKey: K.model) ?? p.defaultModel
        self.targetLanguage       = ud.string(forKey: K.targetLang) ?? "中文"
        self.triggerMode          = TriggerMode(rawValue: ud.string(forKey: K.trigger) ?? "") ?? .selection
        self.interactionMode      = InteractionMode(rawValue: ud.string(forKey: K.interaction) ?? "") ?? .both
        self.useClipboardFallback = (ud.object(forKey: K.clip) as? Bool) ?? true
        self.speechRate           = (ud.object(forKey: K.rate) as? Double) ?? 0.35
        self.englishAccent        = EnglishAccent(rawValue: ud.string(forKey: K.accent) ?? "") ?? .american
        self.enabled              = (ud.object(forKey: K.enabled) as? Bool) ?? true

        // 一次性迁移：DeepSeek 直连的 deepseek-chat / deepseek-reasoner 于 2026-07-24 弃用，
        // 把存量旧值改写成 deepseek-v4-flash（仅 DeepSeek 直连 provider，且只迁一次）。
        if !ud.bool(forKey: K.dsModelMigrated) {
            if p == .deepseek, model == "deepseek-chat" || model == "deepseek-reasoner" {
                model = "deepseek-v4-flash"
            }
            ud.set(true, forKey: K.dsModelMigrated)
        }
    }

    /// 原子地切换服务商：套用新默认值，并加载新 provider 自己的 key。
    /// 不依赖 @Published 的 didSet 触发时序，避免把 A 的 key 串写到 B 账户。
    func switchProvider(to newProvider: LLMProvider) {
        provider = newProvider
        baseURL = newProvider.defaultBaseURL
        model = newProvider.defaultModel
        fetchedModels = []
        // 读取新 provider 在 Keychain 里已存的 key（没有则空）。
        // 这次赋值的 didSet 会用 provider(=newProvider).rawValue 写回同一账户，幂等。
        apiKey = Keychain.read(account: newProvider.rawValue) ?? ""
    }

    /// 兼容旧调用：套用默认 base/model（不动 key）。
    func applyProviderDefaults() {
        baseURL = provider.defaultBaseURL
        model = provider.defaultModel
        fetchedModels = []
    }

    @MainActor func resolved() -> ResolvedSettings {
        ResolvedSettings(apiKey: apiKey, baseURL: baseURL, model: model, targetLanguage: targetLanguage)
    }
}
