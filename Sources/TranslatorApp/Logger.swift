import Foundation

enum Log {
    static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs/TranslatorApp", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("log.txt")
    }()

    private static let queue = DispatchQueue(label: "translator.log")
    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func info(_ msg: String) {
        write("INFO", msg)
    }

    static func warn(_ msg: String) {
        write("WARN", msg)
    }

    static func error(_ msg: String) {
        write("ERR ", msg)
    }

    private static func write(_ level: String, _ msg: String) {
        queue.async {
            let line = "[\(fmt.string(from: Date()))] [\(level)] \(msg)\n"
            guard let data = line.data(using: .utf8) else { return }
            if let h = try? FileHandle(forWritingTo: fileURL) {
                h.seekToEndOfFile()
                h.write(data)
                try? h.close()
            } else {
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }

    static func tail(lines: Int = 200) -> String {
        guard let txt = try? String(contentsOf: fileURL, encoding: .utf8) else { return "(暂无日志)" }
        let arr = txt.split(separator: "\n", omittingEmptySubsequences: false)
        let n = max(0, arr.count - lines)
        return arr[n...].joined(separator: "\n")
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
