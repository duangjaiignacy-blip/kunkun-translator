import Foundation

struct TranslationResult: Codable, Equatable {
    var translation: String
    var pronunciation: String?
    var partOfSpeech: String?
    var definitions: [String]
    var examples: [String]
    /// 是否来自苹果系统离线翻译（断网降级）。离线时只有译文，无音标/释义/例句。
    var isOffline: Bool = false
}

enum LLMError: LocalizedError {
    case missingKey
    case badURL
    case http(Int, String)
    case emptyResponse
    case decode(String)

    var errorDescription: String? {
        switch self {
        case .missingKey:        return "请先在「设置」里填入 API Key。"
        case .badURL:            return "Base URL 不合法。"
        case .http(let c, let m): return "API 返回 \(c)：\(m)"
        case .emptyResponse:     return "API 返回内容为空。"
        case .decode(let s):     return "解析失败：\(s)"
        }
    }
}

actor LLMClient {
    static let shared = LLMClient()

    /// 专用 session：不复用可能已失效的连接，超时更明确。
    /// 裸用 URLSession.shared 在网络刚恢复时容易拿到缓存的坏连接，报 -1005 network lost。
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 60
        cfg.waitsForConnectivity = true   // 网络短暂不可用时等待而非立即失败
        return URLSession(configuration: cfg)
    }()

    /// 发请求 + 对 -1005（network connection lost）自动重试一次。
    /// 这个错误常是连接被中途掐断，重试基本能成。
    private func dataWithRetry(for req: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: req)
        } catch let err as URLError where err.code == .networkConnectionLost {
            Log.warn("网络连接中断(-1005)，重试一次…")
            return try await session.data(for: req)
        }
    }

    // MARK: - 流式翻译（两阶段：先流式译文，再补全释义）

    /// 阶段1：流式翻译，只要译文。逐 token 通过 onDelta 回调（在 MainActor 调）。
    /// 返回完整译文。失败抛错，由调用方决定是否降级。
    func translateStream(text: String, context: String? = nil,
                         onDelta: @MainActor @escaping (String) -> Void) async throws -> String {
        let s = await MainActor.run { SettingsStore.shared.resolved() }
        guard !s.apiKey.isEmpty else { throw LLMError.missingKey }
        let base = s.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let url = URL(string: base + "/chat/completions") else { throw LLMError.badURL }

        let system = "你是一个高效的翻译助手。\(Self.translationTargetInstruction(for: text))只输出译文本身，不要任何解释、音标、词性、例句、引号或多余的话。若是句子就直接给通顺的整句翻译。"
        var user = text
        if let ctx = context, !ctx.isEmpty, ctx != text {
            user = "翻译这段：\"\(text)\"（上下文参考，勿翻译上下文：\"\(ctx)\"）"
        }
        let body: [String: Any] = [
            "model": s.model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ],
            "temperature": 0.3,
            "max_tokens": 400,
            "stream": true
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(s.apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 30
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, resp) = try await session.bytes(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            // 出错时把 body 读出来给出可读信息
            var msg = ""
            for try await line in bytes.lines { msg += line; if msg.count > 500 { break } }
            throw LLMError.http(http.statusCode, msg)
        }

        var full = ""
        for try await line in bytes.lines {
            // SSE 行形如: data: {"choices":[{"delta":{"content":"记"}}]}
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let d = payload.data(using: .utf8) else { continue }
            if let piece = Self.parseDeltaContent(d), !piece.isEmpty {
                full += piece
                let snapshot = full
                await MainActor.run { onDelta(snapshot) }
            }
        }
        let cleaned = full.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw LLMError.emptyResponse }
        return cleaned
    }

    /// 从一个 SSE data 块里取 delta.content。
    private static func parseDeltaContent(_ data: Data) -> String? {
        struct Chunk: Decodable {
            struct Choice: Decodable {
                struct Delta: Decodable { let content: String? }
                let delta: Delta?
            }
            let choices: [Choice]
        }
        guard let c = try? JSONDecoder().decode(Chunk.self, from: data) else { return nil }
        return c.choices.first?.delta?.content
    }

    /// 阶段2：译文已就绪后，补全音标/词性/释义/例句（非流式，短请求）。
    /// 失败返回 nil（卡片就只显示译文，不报错打扰）。
    func enrich(text: String, translation: String) async -> TranslationResult? {
        let s = await MainActor.run { SettingsStore.shared.resolved() }
        guard !s.apiKey.isEmpty else { return nil }
        let base = s.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let url = URL(string: base + "/chat/completions") else { return nil }

        // 整句不补释义（省时），只有单词/短语才补。中文没有空格，单独用字数兜底。
        let isChineseSource = Self.containsCJK(text)
        let wordCount = text.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
        let isShortInput = isChineseSource ? text.count <= 8 : wordCount <= 4
        guard isShortInput else {
            return TranslationResult(translation: translation, pronunciation: nil,
                                     partOfSpeech: nil, definitions: [], examples: [], isOffline: false)
        }

        let sourceDescription = isChineseSource ? "中文词语/短语及其英文译文" : "英文单词/短语及其中文译文"
        let jsonShape = isChineseSource
            ? #"{"pronunciation":"","partOfSpeech":"词性或短语类型，可空","definitions":["最多2条中文释义"],"examples":["1条例句 — 英文翻译"]}"#
            : #"{"pronunciation":"美式音标，可空","partOfSpeech":"词性如 n./v.，可空","definitions":["最多2条核心释义"],"examples":["1条例句 — 中文翻译"]}"#
        let system = """
        用户给你一个\(sourceDescription)。请补充信息，严格只输出 JSON，不要 markdown 或多余的话：
        \(jsonShape)
        字段值只能是字符串或字符串数组，不要嵌套对象。
        """
        let body: [String: Any] = [
            "model": s.model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": "单词/短语：\(text)\n译文：\(translation)"]
            ],
            "temperature": 0.3,
            "max_tokens": 400,
            "response_format": ["type": "json_object"]
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(s.apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 30
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        req.httpBody = httpBody

        guard let (data, resp) = try? await dataWithRetry(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }

        struct Resp: Decodable {
            struct Choice: Decodable { struct Msg: Decodable { let content: String }; let message: Msg }
            let choices: [Choice]
        }
        guard let parsed = try? JSONDecoder().decode(Resp.self, from: data),
              let content = parsed.choices.first?.message.content else { return nil }

        // 用健壮的对象提取拿到各字段，再和已有译文 merge（译文以流式结果为准）
        let obj = Self.extractLooseObject(content)
        return TranslationResult(
            translation: translation,
            pronunciation: Self.nonEmpty(Self.stringValue(obj?["pronunciation"])),
            partOfSpeech: Self.nonEmpty(Self.stringValue(obj?["partOfSpeech"])),
            definitions: Self.stringArray(obj?["definitions"]),
            examples: Self.exampleArray(obj?["examples"]),
            isOffline: false
        )
    }

    /// enrich 专用：宽松提取 JSON 对象（复用主解析器的清洗与括号配对）。
    private static func extractLooseObject(_ content: String) -> [String: Any]? {
        return extractFirstJSONObject(content)
    }

    /// 对外入口：云端优先，断网/无 key 时降级到苹果系统离线翻译。
    func translate(text: String, context: String? = nil) async throws -> TranslationResult {
        do {
            return try await translateViaCloud(text: text, context: context)
        } catch {
            // 仅在「网络不可用 / 没填 key」这类情况降级；其它错误（如 JSON 解析）照常抛出。
            if Self.shouldFallbackOffline(error) {
                Log.info("云端翻译不可用（\(error.localizedDescription)），尝试苹果离线翻译降级")
                if let offline = await Self.translateOffline(text: text) {
                    return offline
                }
            }
            throw error
        }
    }

    /// 判断某个错误是否该触发离线降级。
    private static func shouldFallbackOffline(_ error: Error) -> Bool {
        if case LLMError.missingKey = error { return true }
        if let urlErr = error as? URLError {
            switch urlErr.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
                 .dataNotAllowed, .internationalRoamingOff:
                return true
            default:
                return false
            }
        }
        return false
    }

    /// 调用苹果系统离线翻译，包成 TranslationResult（只有译文）。
    private static func translateOffline(text: String) async -> TranslationResult? {
        guard #available(macOS 15.0, *) else {
            Log.warn("系统版本 < macOS 15，无苹果离线翻译")
            return nil
        }
        let target = await MainActor.run {
            appleTargetCode(Self.translationTargetLanguage(for: text))
        }
        guard let translated = await AppleTranslator.shared.translate(text, target: target),
              !translated.isEmpty else {
            return nil
        }
        return TranslationResult(
            translation: translated,
            pronunciation: nil, partOfSpeech: nil,
            definitions: [], examples: [], isOffline: true
        )
    }

    /// 把用户的目标语言文案映射成苹果 Locale.Language 代码。
    private static func appleTargetCode(_ targetLanguage: String) -> String {
        let t = targetLanguage.lowercased()
        if t.contains("中") || t.contains("chinese") || t.contains("zh") { return "zh-Hans" }
        if t.contains("英") || t.contains("english") || t.contains("en") { return "en" }
        if t.contains("日") || t.contains("japanese") { return "ja" }
        if t.contains("韩") || t.contains("korean") { return "ko" }
        if t.contains("法") || t.contains("french") { return "fr" }
        if t.contains("德") || t.contains("german") { return "de" }
        if t.contains("西") || t.contains("spanish") { return "es" }
        return "zh-Hans"
    }

    private func translateViaCloud(text: String, context: String? = nil) async throws -> TranslationResult {
        let s = await MainActor.run { SettingsStore.shared.resolved() }
        guard !s.apiKey.isEmpty else { throw LLMError.missingKey }
        let base = s.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let url = URL(string: base + "/chat/completions") else { throw LLMError.badURL }

        let system = """
        你是一个高效的中英双向翻译助手，追求快速简洁。\(Self.translationTargetInstruction(for: text))
        严格只输出一个 JSON 对象，不要 markdown、不要任何解释或前后缀。字段值只能是字符串或字符串数组，不允许嵌套对象。结构：
        {"translation":"翻译","pronunciation":"美式音标，可空","partOfSpeech":"词性如 n./v./adj.，可空","definitions":["释义"],"examples":["例句 — 翻译"]}
        规则（务必精简以加快速度）：
        - 若是单词/短语：definitions 最多 2 条最核心释义；examples 最多 1 条例句。
        - 若是整句：只给 translation，其余字段留空（pronunciation="" partOfSpeech="" definitions=[] examples=[]）。
        - examples 每项是单个字符串，用「 — 」连接英文和中文，不要 {en,zh} 对象。
        """

        var user = "请翻译: \"\(text)\""
        if let ctx = context, !ctx.isEmpty, ctx != text {
            user += "\n上下文（仅参考，不要翻译上下文）: \"\(ctx)\""
        }

        let body: [String: Any] = [
            "model": s.model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user",   "content": user]
            ],
            "temperature": 0.3,
            "max_tokens": 512,   // 翻译输出很短，限制上限避免模型话痨、加快返回
            "response_format": ["type": "json_object"]
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(s.apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 30
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await dataWithRetry(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.http(http.statusCode, msg)
        }

        struct Resp: Decodable {
            struct Choice: Decodable { let message: Msg }
            struct Msg: Decodable { let content: String }
            let choices: [Choice]
        }
        let parsed: Resp
        do { parsed = try JSONDecoder().decode(Resp.self, from: data) }
        catch { throw LLMError.decode(error.localizedDescription) }
        guard let content = parsed.choices.first?.message.content else { throw LLMError.emptyResponse }

        return Self.parseTranslationResult(from: content, stripCodeFence: stripCodeFence)
    }

    private static func translationTargetLanguage(for text: String) -> String {
        containsCJK(text) ? "英文" : "中文"
    }

    private static func translationTargetInstruction(for text: String) -> String {
        if containsCJK(text) {
            return "如果输入主要是中文，请翻译成英文。"
        }
        return "如果输入主要不是中文，请翻译成中文。"
    }

    private static func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value) ||
            (0x3400...0x4DBF).contains(scalar.value) ||
            (0xF900...0xFAFF).contains(scalar.value)
        }
    }

    /// 健壮解析 LLM 返回文本 → TranslationResult。
    /// GLM/DeepSeek 等模型不严格遵守 response_format，返回常有噪声（前后多话、
    /// examples 是对象数组、字段缺失、中文引号、trailing comma 等）。
    /// 策略：①严格 decode；②失败则提取首个 {...} 逐字段宽松取值；③绝不把原始 JSON 甩给用户。
    static func parseTranslationResult(from content: String, stripCodeFence: (String) -> String) -> TranslationResult {
        // 去 BOM / 零宽字符再剥围栏
        let deBOM = content.replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\u{200B}", with: "")
        let cleaned = stripCodeFence(deBOM)

        // ① 严格解码（正常路径），要求 translation 非空才算成功，否则往下救。
        if let d = cleaned.data(using: .utf8),
           let r = try? JSONDecoder().decode(TranslationResult.self, from: d),
           !r.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return r
        }

        // ② 从文本里抠出第一个花括号对象，逐字段宽松取
        if let obj = extractFirstJSONObject(cleaned) {
            let translation = stringValue(obj["translation"]) ?? ""
            // translation 有值才算解析成功（否则往下走降级）
            if !translation.isEmpty {
                return TranslationResult(
                    translation: translation,
                    pronunciation: nonEmpty(stringValue(obj["pronunciation"])),
                    partOfSpeech: nonEmpty(stringValue(obj["partOfSpeech"])),
                    definitions: stringArray(obj["definitions"]),
                    examples: exampleArray(obj["examples"]),
                    isOffline: false
                )
            }
        }

        // ③ 彻底失败：绝不显示原始 JSON。取纯文本兜底，实在没有就给提示。
        let plain = cleaned.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let looksLikeJSON = plain.hasPrefix("{") || plain.hasPrefix("[")
        return TranslationResult(
            translation: looksLikeJSON ? "（翻译结果格式异常，请重试或换个模型）" : plain,
            pronunciation: nil, partOfSpeech: nil, definitions: [], examples: [], isOffline: false
        )
    }

    // MARK: - 宽松取值辅助

    /// 从可能含噪声的文本里提取第一个完整的 JSON 对象。
    private static func extractFirstJSONObject(_ rawText: String) -> [String: Any]? {
        // 先归一全角标点/中文引号，再做括号配对——否则中文引号让 inString 判断失灵。
        let text = repairJSONNoise(rawText)
        guard let start = text.firstIndex(of: "{") else {
            // 根节点可能是数组 [{...}]，取第一个元素
            if let arrStart = text.firstIndex(of: "["),
               let braceStart = text[arrStart...].firstIndex(of: "{") {
                return extractFirstJSONObject(String(text[braceStart...]))
            }
            return nil
        }
        // 从第一个 { 起做括号配对，找到匹配的 }
        var depth = 0
        var inString = false
        var escaped = false
        var end: String.Index?
        var i = start
        while i < text.endIndex {
            let c = text[i]
            if escaped { escaped = false }
            else if c == "\\" { escaped = true }
            else if c == "\"" { inString.toggle() }
            else if !inString {
                if c == "{" { depth += 1 }
                else if c == "}" { depth -= 1; if depth == 0 { end = i; break } }
            }
            i = text.index(after: i)
        }
        guard let e = end else { return nil }
        let slice = String(text[start...e])

        // 先直接试；失败再做「中文标点/尾逗号」清洗后重试。
        if let data = slice.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return obj
        }
        let repaired = repairJSONNoise(slice)
        guard let data = repaired.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj
    }

    /// 修复 LLM 常见的 JSON 噪声：字符串内裸换行/制表符（转义）、
    /// 结构位置的全角标点（归一）、尾逗号。用状态机区分「字符串内 vs 结构位置」，
    /// 避免误改译文内容里的合法字符。
    private static func repairJSONNoise(_ raw: String) -> String {
        // 第一步：全局把中文/智能引号统一成 ASCII 双引号（字符串内外都要），
        // 全角冒号/逗号归一。这些字符不会出现在合法 JSON 结构里，替换是安全的。
        var t = raw
        for q in ["“", "”", "„", "‟", "＂", "「", "」"] {
            t = t.replacingOccurrences(of: q, with: "\"")
        }
        t = t.replacingOccurrences(of: "：", with: ":")
        t = t.replacingOccurrences(of: "，", with: ",")

        // 第二步：状态机转义字符串内的裸换行/制表符（这些必须区分字符串内外）。
        var out = [Character]()
        out.reserveCapacity(t.count)
        var inString = false
        var escaped = false
        for c in t {
            if inString {
                if escaped { escaped = false; out.append(c) }
                else if c == "\\" { escaped = true; out.append(c) }
                else if c == "\"" { inString = false; out.append(c) }
                else if c == "\n" || c == "\r" { out.append("\\"); out.append("n") }
                else if c == "\t" { out.append("\\"); out.append("t") }
                else { out.append(c) }
            } else {
                if c == "\"" { inString = true }
                out.append(c)
            }
        }
        var result = String(out)
        // 第三步：去尾逗号 ,} 或 ,]
        result = result.replacingOccurrences(of: #",\s*}"#, with: "}", options: .regularExpression)
        result = result.replacingOccurrences(of: #",\s*]"#, with: "]", options: .regularExpression)
        return result
    }

    private static func stringValue(_ v: Any?) -> String? {
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        return nil
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        return s
    }

    private static func stringArray(_ v: Any?) -> [String] {
        // 兼容模型把数组写成单个标量字符串的情况
        if let s = stringValue(v), !s.isEmpty { return [s] }
        guard let arr = v as? [Any] else { return [] }
        return arr.compactMap { stringValue($0) }.filter { !$0.isEmpty }
    }

    /// examples 兼容三种形态：[String]、[{en,zh}] 对象数组、单个字符串。
    private static func exampleArray(_ v: Any?) -> [String] {
        if let s = v as? String, !s.isEmpty { return [s] }
        guard let arr = v as? [Any] else { return [] }
        return arr.compactMap { item -> String? in
            if let s = item as? String { return s.isEmpty ? nil : s }
            if let dict = item as? [String: Any] {
                // 常见键：en/zh, source/target, original/translation, text/trans
                let en = stringValue(dict["en"]) ?? stringValue(dict["source"])
                    ?? stringValue(dict["original"]) ?? stringValue(dict["text"]) ?? stringValue(dict["english"])
                let zh = stringValue(dict["zh"]) ?? stringValue(dict["target"])
                    ?? stringValue(dict["translation"]) ?? stringValue(dict["trans"]) ?? stringValue(dict["chinese"])
                let parts = [en, zh].compactMap { $0 }.filter { !$0.isEmpty }
                return parts.isEmpty ? nil : parts.joined(separator: " — ")
            }
            return nil
        }
    }

    func summarize(words: [String]) async throws -> String {
        let s = await MainActor.run { SettingsStore.shared.resolved() }
        guard !s.apiKey.isEmpty else { throw LLMError.missingKey }
        let base = s.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let url = URL(string: base + "/chat/completions") else { throw LLMError.badURL }

        let system = "你是一个英语学习助手。用户会给你一份最近收集的英文单词/短语列表。请用\(s.targetLanguage)做一份学习总结，包括：主题分类、难度估计、记忆建议、5 句使用这些词的连贯短文。用 Markdown 输出。"
        let body: [String: Any] = [
            "model": s.model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": "词表（共 \(words.count) 个）：\n\(words.joined(separator: ", "))"]
            ],
            "temperature": 0.6
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(s.apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 60
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await dataWithRetry(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            throw LLMError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        struct Resp: Decodable {
            struct Choice: Decodable { let message: Msg }
            struct Msg: Decodable { let content: String }
            let choices: [Choice]
        }
        let parsed = try JSONDecoder().decode(Resp.self, from: data)
        return parsed.choices.first?.message.content ?? ""
    }

    private func stripCodeFence(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            if let r = t.range(of: "\n") { t = String(t[r.upperBound...]) }
            if let r = t.range(of: "```", options: .backwards) { t = String(t[..<r.lowerBound]) }
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
