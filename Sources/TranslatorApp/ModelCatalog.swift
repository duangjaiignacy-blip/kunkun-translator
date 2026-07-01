import Foundation

/// 硅基流动（及其它 OpenAI 兼容服务商）的模型清单管理。
///
/// 设计原则：**在线拉取为主，兜底清单为辅**。
/// 用户填好 Key 后点「刷新模型列表」，App 调 `GET /v1/models` 拿回当时真实在线的
/// 全量 model id —— 永远不会过期。兜底清单只是没刷新前的占位，按硅基流动
/// `厂商命名空间/模型名` 的稳定规范给几个常用项，UI 会提示用户刷新获取最新。
enum ModelCatalog {

    /// 硅基流动兜底精选（未联网刷新时用）。
    /// 注意：硅基流动 model id 形如 `deepseek-ai/DeepSeek-V3`，带厂商命名空间。
    /// 下面这些 id 于 2026-07 联网核实过命名空间与在线情况；但平台模型更新很快，
    /// **以 App 内「刷新」按钮拉到的 /v1/models 实时结果为准**。
    /// 小米 MiMo 暂未确认其在硅基流动的命名空间，故未列入——点「刷新」即可看到当前是否上架。
    static let siliconflowFallback: [String] = [
        "deepseek-ai/DeepSeek-V3",        // DeepSeek 通用对话
        "deepseek-ai/DeepSeek-R1",        // DeepSeek 推理
        "zai-org/GLM-4.6",                // 智谱 GLM（命名空间已迁至 zai-org）
        "zai-org/GLM-4.5",                // 智谱 GLM 上一代
        "MiniMaxAI/MiniMax-M1",           // MiniMax
        "Qwen/Qwen2.5-72B-Instruct"       // 通义千问（备选）
    ]

    /// 拉取在线模型列表。`type=text` 只要文本对话模型。
    /// 成功返回排序后的 model id 数组；失败抛错由调用方提示。
    static func fetchModels(baseURL: String, apiKey: String) async throws -> [String] {
        let base = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard !apiKey.isEmpty else { throw LLMError.missingKey }
        guard var comps = URLComponents(string: base + "/models") else { throw LLMError.badURL }
        comps.queryItems = [URLQueryItem(name: "type", value: "text")]
        guard let url = comps.url else { throw LLMError.badURL }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 20

        // 用 ephemeral session，避免复用刚恢复网络时的坏连接（-1005）。
        let cfg = URLSessionConfiguration.ephemeral
        cfg.waitsForConnectivity = true
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: cfg)

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await session.data(for: req)
        } catch let err as URLError where err.code == .networkConnectionLost {
            (data, resp) = try await session.data(for: req)  // -1005 重试一次
        }
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            throw LLMError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        struct ModelsResp: Decodable {
            struct Model: Decodable { let id: String }
            let data: [Model]
        }
        let parsed: ModelsResp
        do { parsed = try JSONDecoder().decode(ModelsResp.self, from: data) }
        catch { throw LLMError.decode(error.localizedDescription) }

        let ids = parsed.data.map(\.id).filter { !$0.isEmpty }
        guard !ids.isEmpty else { throw LLMError.emptyResponse }
        // 按厂商命名空间分组排序，方便在下拉里找
        return ids.sorted { $0.lowercased() < $1.lowercased() }
    }
}
