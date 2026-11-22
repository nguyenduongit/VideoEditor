import Foundation
import Supabase
import os

/// Quản lý cấu hình kết nối Supabase client
/// Đọc từ biến môi trường hệ thống, fallback về file `.env` (không commit — R9.3).
public enum SupabaseConfig {
    private static let logger = Logger(subsystem: "VideoEditor", category: "SupabaseConfig")

    /// Khởi tạo duy nhất 1 SupabaseClient chia sẻ cho toàn bộ ứng dụng (Composition Root).
    public static let sharedClient: SupabaseClient? = makeClient()

    public static func makeClient() -> SupabaseClient? {
        let env = ProcessInfo.processInfo.environment
        let envFile = loadEnvFile()
        let urlString = env["SUPABASE_URL"] ?? envFile["SUPABASE_URL"] ?? ""
        let key = env["SUPABASE_PUBLISHABLE_KEY"] ?? envFile["SUPABASE_PUBLISHABLE_KEY"] ?? ""
        guard let url = URL(string: urlString), !urlString.isEmpty, !key.isEmpty else {
            logger.error("Missing SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY (env or .env); skipping online sync")
            return nil
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25.0
        config.timeoutIntervalForResource = 60.0
        config.waitsForConnectivity = true
        let session = URLSession(configuration: config)

        let options = SupabaseClientOptions(global: .init(session: session))
        return SupabaseClient(supabaseURL: url, supabaseKey: key, options: options)
    }

    private static func loadEnvFile() -> [String: String] {
        let candidateURLs = [
            Bundle.main.url(forResource: ".env", withExtension: nil),
            Bundle.main.resourceURL?.appendingPathComponent(".env"),
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("VideoEditor/.env"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".env")
        ].compactMap { $0 }

        for envURL in candidateURLs {
            if let content = try? String(contentsOf: envURL, encoding: .utf8) {
                let parsed = parseEnvContent(content)
                if !parsed.isEmpty {
                    return parsed
                }
            }
        }
        return [:]
    }

    private static func parseEnvContent(_ content: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                var val = parts[1].trimmingCharacters(in: .whitespaces)
                if (val.hasPrefix("\"") && val.hasSuffix("\"")) || (val.hasPrefix("'") && val.hasSuffix("'")) {
                    val = String(val.dropFirst().dropLast())
                }
                result[key] = val
            }
        }
        return result
    }
}
