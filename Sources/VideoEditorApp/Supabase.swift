import Foundation
import Supabase
@_exported import PostgREST

extension PostgrestResponse: @unchecked @retroactive Sendable where T: Sendable {}

let supabase = SupabaseClient(
  supabaseURL: URL(string: "https://cbtfcbkczilkwngrxwgt.supabase.co")!,
  supabaseKey: "sb_publishable_slaMIVdTU6RIrJJi9nSqEw_lh2CSGXL"
)
