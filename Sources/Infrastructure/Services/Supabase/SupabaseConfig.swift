import Foundation
import Supabase
import os

/// Quản lý cấu hình kết nối Supabase client
/// Đọc từ biến môi trường hệ thống, fallback về file `.env` (không commit — R9.3).
public enum SupabaseConfig {
    private static let logger = Logger(subsystem: "VideoEditor", category: "SupabaseConfig")

    public static func makeClient() -> SupabaseClient? {
        let env = ProcessInfo.processInfo.environment
        let envFile = loadEnvFile()
        let urlString = env["SUPABASE_URL"] ?? envFile["SUPABASE_URL"] ?? ""
        let key = env["SUPABASE_PUBLISHABLE_KEY"] ?? envFile["SUPABASE_PUBLISHABLE_KEY"] ?? ""
        guard let url = URL(string: urlString), !urlString.isEmpty, !key.isEmpty else {
            logger.error("Thiếu SUPABASE_URL hoặc SUPABASE_PUBLISHABLE_KEY (env hoặc .env); bỏ qua đồng bộ online")
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
        let cwd = FileManager.default.currentDirectoryPath
        let envURL = URL(fileURLWithPath: cwd).appendingPathComponent(".env")
        guard let content = try? String(contentsOf: envURL, encoding: .utf8) else { return [:] }
        var result: [String: String] = [:]
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                result[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        return result
    }
}
