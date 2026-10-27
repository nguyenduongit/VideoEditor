import Foundation
import Infrastructure
import Supabase
@_exported import PostgREST

extension PostgrestResponse: @unchecked @retroactive Sendable where T: Sendable {}

/// Client dùng cho màn hình demo `ContentView`. Cấu hình lấy từ `SupabaseConfig` (env / .env) — R9.3, R10.1.
let supabase: SupabaseClient? = SupabaseConfig.makeClient()
