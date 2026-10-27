import Foundation
import Supabase

/// Quản lý cấu hình kết nối Supabase client
/// Ưu tiên biến môi trường hệ thống, tự động fallback về cấu hình dự án mặc định.
public enum SupabaseConfig {
    public static let defaultURL = "https://cbtfcbkczilkwngrxwgt.supabase.co"
    public static let defaultAnonKey = "sb_publishable_slaMIVdTU6RIrJJi9nSqEw_lh2CSGXL"

    public static func makeClient() -> SupabaseClient? {
        let env = ProcessInfo.processInfo.environment
        let envFile = loadEnvFile()
        let urlString = env["SUPABASE_URL"] ?? envFile["SUPABASE_URL"] ?? defaultURL
        let key = env["SUPABASE_PUBLISHABLE_KEY"] ?? envFile["SUPABASE_PUBLISHABLE_KEY"] ?? defaultAnonKey
        guard let url = URL(string: urlString), !key.isEmpty else { return nil }

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
