# ADR-004: Supabase Cloud Preset Synchronization & Safe Upsert Governance

## Status
Accepted

## Date
2026-11-07

## Context
`VideoEditor` là ứng dụng dựng phim nội bộ trên macOS 14+ (không phát hành lên Mac App Store) cần đồng bộ trực tuyến kho mẫu sáng tạo dùng chung cho toàn đội ngũ và AI Agent qua 6 phân hệ:
1. `text_presets` (Mẫu chữ đơn dòng 1-Layer + Background + Animation)
2. `animation_presets` (Hoạt ảnh `In / Out / Loop` dùng chung cho `Text` và `Sticker`)
3. `sticker_presets` (Vector `SVG` nội tuyến / `GIF` / `APNG`)
4. `transition_presets` (8 họ Kernel GPU 2-Texture + MSL tùy chỉnh + tham số động)
5. `adjustment_presets` (Color Grading / 3D LUT / Wheels / RGB Curves / Film Grain)
6. `effect_presets` (Metal Compute Effects & Filter Pipeline)
cùng bảng `editor_actions` cho bảng tác vụ tự động.

Quy tắc nền tảng của dự án ưu tiên 100% Apple SDK và cô lập tuyệt đối các thư viện mạng/đám mây khỏi tầng nghiệp vụ (`Domain`) và giao diện (`FeatureShell`). Đồng thời, quá trình khởi tạo mẫu hệ thống (`seed`) tuyệt đối không được phép xóa trắng bảng dữ liệu cộng đồng trên đám mây.

## Decision
1. **Cô lập SDK ngoại vi duy nhất tại `Infrastructure`:** Cho phép sử dụng `supabase-swift` **chỉ bên trong target `Infrastructure`** (`Sources/Infrastructure/Services/Supabase/`). Các target `Domain`, `DesignSystem` và `FeatureShell` hoàn toàn không biết đến `Supabase` và chỉ giao tiếp qua các giao thức thuần Swift 6 `Sendable` trong `PresetRepositoryProtocols.swift` được tiêm từ Composition Root (`AppMain.swift`).
2. **Cơ chế Offline-First SWR & Safe Upsert bắt buộc:**
   - Nghiêm cấm mọi truy vấn xóa hàng loạt (như `.delete().neq(...)`).
   - Toàn bộ thao tác lưu và khởi tạo danh mục hệ thống bắt buộc đi qua `.upsert(..., onConflict: "id")` kết hợp bảo toàn dữ liệu người dùng hiện hữu (`seedSystemCatalogSafely(preserving:)`).
   - Khi ngoại tuyến hoặc chưa cấu hình biến môi trường Supabase (`client == nil`), toàn bộ 6 kho tự động chuyển mượt về bộ đệm RAM (`*TemplateLoader` đồng bộ khóa `NSLock`) cùng danh mục mặc định tích hợp sẵn.

## Consequences

### Positive
- Giữ sạch 100% ranh giới kiến trúc SPM (`Domain` chỉ phụ thuộc `Foundation`/`CoreMedia`/`CoreGraphics`; `FeatureShell` không phụ thuộc `Infrastructure`).
- Đảm bảo an toàn dữ liệu đám mây, không bao giờ làm mất mẫu của người dùng khi cập nhật phiên bản ứng dụng mới.
- Toàn bộ bài kiểm thử tự động chạy tất định 100% ở chế độ cô lập (`client: nil`) không phụ thuộc mạng ngoài.

### Trade-offs & Risks
- Thêm một phụ thuộc SPM bên thứ ba (`supabase-swift`) vào quá trình biên dịch của target `Infrastructure`.
- **Giảm thiểu:** Đóng gói chặt qua Protocol tại `Domain`, kiểm soát tự động bằng `Scripts/check_imports.sh` để ngăn rò rỉ `import Supabase` hoặc `import Infrastructure` sang các tầng khác.

## Scope & Target Modules
- `Package.swift` (chỉ gắn dependency `Supabase` vào target `Infrastructure`)
- `Sources/Domain/Preset/PresetRepositoryProtocols.swift`
- `Sources/Infrastructure/Services/Supabase/Supabase*Repository.swift`
- `Sources/VideoEditorApp/AppMain.swift`

## Approval
Approved by: Project Owner (Approved via Implementation Plan Gate)  
Date: 2026-11-06
