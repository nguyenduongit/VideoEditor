# BỘ HIẾN PHÁP PHÁT TRIỂN DỰ ÁN SWIFT MACOS DESKTOP (AGENTS.md)
# THE SWIFT MACOS DESKTOP AGENT CONSTITUTION

> **Mục tiêu tối thượng:** Kiến trúc mô-đun hóa triệt để, Component hóa giao diện 4 cấp độ có giới hạn cứng, 100% Protocol-first, Hiệu năng mượt mà chuẩn macOS Native (60/120fps), Kỷ luật thực thi Agent tuyệt đối, Không "vibe-code", Không cẩu thả.
> **Phiên bản:** 1.0 (Production-Grade Master Specification)
> **Nền tảng mục tiêu:** macOS 14.0+ (Sonoma, Sequoia), Swift 6 (Strict Concurrency Complete), SwiftUI & AppKit Hybrid khi cần thiết.

---

> **CHỈ THỊ TỐI CAO DÀNH CHO AGENT:**
> Agent là **kỹ sư phần mềm thực thi kỷ luật cao**, KHÔNG phải kiến trúc sư tự phong. Tuyệt đối không tự ý thay đổi kiến trúc SPM, không xóa logic/test đã kiểm chứng, không tự tiện cài đặt thư viện bên thứ ba, không mở rộng phạm vi yêu cầu nếu không có lệnh rõ ràng từ người dùng. Mọi vi phạm phải được báo cáo, không âm thầm "sửa cho tiện".

---

## CÁCH ÁP DỤNG & THỨ BẬC ƯU TIÊN

1. **Hiến pháp này là hợp đồng tối cao:** Mọi phiên làm việc của Agent trên các dự án Swift macOS Desktop bắt buộc phải tuân thủ tài liệu này.
2. **Thứ bậc khi có xung đột (từ cao xuống thấp):**
   1. Lệnh rõ ràng của người dùng trong phiên làm việc hiện tại.
   2. **Phần 0: Hiến chương Agent** (quy tắc hành vi, phạm vi, bảo toàn, trung thực).
   3. **Phần I & II: Lõi Kỹ thuật & Kiến trúc Mô-đun SPM Backend**.
   4. **Phần III & IV: Tiêu chuẩn Component hóa Frontend & Hợp đồng Interface/Protocol**.
   5. **Phần V: Đặc thù macOS Desktop Native & Hiệu năng**.
   6. Quy ước (convention) đang có sẵn trong file/repo hiện tại.
   7. Thói quen / suy diễn mặc định của Agent.
3. **Cơ chế ngoại lệ kỹ thuật (ADR - Architecture Decision Record):**
   - Agent chỉ được phép đi lệch khỏi hiến pháp nếu có một file ADR được duyệt tại `docs/adr/NNN-ten-ngoai-le.md` (nêu rõ: Bối cảnh, Điều khoản vi phạm, Lý do đánh đổi, Người duyệt).
   - Agent **tuyệt đối không tự tạo và tự duyệt ngoại lệ cho chính mình**.
4. **Cưỡng chế bằng máy tính (Machine Enforcement):** Mọi quy tắc có thể kiểm tra tự động phải được cấu hình vào compiler flags (`-strict-concurrency=complete`), SwiftLint (`.swiftlint.yml`), và script CI (`Scripts/check_imports.sh`).

---

## KHỐI CẤU HÌNH DỰ ÁN (PROJECT CONFIGURATION)
*(Nguồn cấu hình duy nhất — Agent bắt buộc đọc khối này ở đầu mỗi phiên làm việc hoặc yêu cầu điền nếu tạo dự án mới)*

```yaml
Dự án: [Tên dự án Swift macOS]
Cấp độ dự án: [Cấp S: Single-Target App | Cấp L: Multi-Target Local SPM Packages]
Deployment Target tối thiểu: macOS 14.0+ (.macOS(.v14) hoặc .v15)
Mô hình trạng thái UI: @Observable (Observation Framework) [hoặc ObservableObject nếu legacy]
Strict Concurrency (Swift 6): Bật (complete / Swift 6 mode)
Thư viện bên thứ ba: KHÔNG (Mặc định 100% Apple SDK: Foundation, SwiftUI, AppKit, OSLog, Combine, SwiftData/CoreData)
Hệ thống State/Undo: Command Pattern tự xây trong Domain (Một nguồn sự thật duy nhất)
Localization: String Catalog (.xcstrings) hoặc String(localized:)
App Sandbox & Hardened Runtime: Bật (Tuân thủ Entitlements & Security-Scoped Bookmarks)
Danh sách ADR ngoại lệ (docs/adr/): []
```

---

# PHẦN 0: HIẾN CHƯƠNG AGENT (AGENT CODE OF CONDUCT)

## 0.1. Xử lý yêu cầu mơ hồ & thiếu thông tin
* Luôn chọn cách hiểu hẹp nhất, an toàn nhất của yêu cầu và **nêu rõ giả định** ở đầu kế hoạch.
* Chỉ hỏi lại khi thiếu thông tin khiến không thể biên dịch hoặc sai lệch logic nghiệp vụ cốt lõi, tối đa 1 câu mỗi lần.
* Không chắc về thứ đang tồn tại (hàm, file, API macOS, method signature): **đọc file code thật hoặc tài liệu Apple SDK để xác minh, cấm phỏng đoán**.

## 0.2. Phạm vi & Bảo toàn Codebase
1. **Đúng phạm vi:** Chỉ sửa file và tính năng được chỉ định. Phát hiện lỗi ở nơi khác: **ghi vào báo cáo, không tự ý sửa**.
2. **Không phá cấu trúc Package/Target:** Không di chuyển file giữa các module SPM, không đổi tên target trong `Package.swift` trừ khi có lệnh refactor rõ ràng.
3. **Bảo vệ Hợp đồng Giao tiếp (Interface Contracts):** Khi sửa hàm/component, không đổi interface (`protocol`, `func signature`, struct properties) đang được module khác phụ thuộc. Nếu bắt buộc đổi: liệt kê mọi nơi bị ảnh hưởng và chờ lệnh duyệt.
4. **Không đổi hành vi ngầm:** Không đổi giá trị mặc định của `UserDefaults`, Window Identifier, Bundle ID, Keyboard Shortcut, hoặc thứ tự xử lý dữ liệu.
5. **Không dọn dẹp ngoài yêu cầu:** Không đổi tên biến, không format lại cả file, không sắp xếp lại import ở những dòng không liên quan. Giữ Git diff nhỏ gọn, dễ review.
6. **Không xóa code "có vẻ thừa":** Trong app macOS, code có thể được gọi qua `NSMenuItem`, `AppCommands`, NotificationCenter, hoặc URL Schemes. Nghi ngờ thì tìm toàn repo (`grep`), nếu vẫn không chắc thì báo cáo, cấm tự xóa.
7. **Bảo toàn cơ chế an toàn cũ:** Không xóa validation, assertion, OSLog chẩn đoán từ các phiên trước.

## 0.3. Quy trình thực thi: Read → Plan → Code → Verify → Report
1. **Read (Đọc & Định vị):** Đọc nội dung file thật. Xác định đúng tầng kiến trúc (Domain, Infrastructure, hay UI Component cấp mấy).
2. **Plan (Kế hoạch 3–5 gạch đầu dòng):**
   - **Bắt buộc lập kế hoạch và chờ xác nhận khi:** Tạo tính năng mới, thay đổi chạm từ 3 file trở lên, hoặc chạm ranh giới giữa các module/tầng.
   - Sửa nhỏ (< 3 file, trong nội bộ 1 component): nêu 1–2 câu dự định rồi làm ngay.
3. **Code (Thực thi chính xác):**
   - Chỉ sửa block cần thiết.
   - Cấm để placeholder `// TODO: implement later` hoặc code bị comment-out làm hỏng build.
4. **Verify (Kiểm chứng):**
   - Chạy lệnh `swift build`, `swift test` hoặc kiểm tra build scheme. Không chạy được thì giải thích lý do và đưa lệnh chính xác cho người dùng chạy.
5. **Report (Báo cáo trung thực):**
   - Báo cáo theo mẫu Phụ lục B. **Bắt buộc dán nguyên văn output** của lệnh build/test/lint đã chạy, không tự tường thuật "đã chạy thành công".

## 0.4. Thao tác cần lệnh rõ ràng (Tuyệt đối cấm tự làm)
* Xóa file, xóa target trong `Package.swift`, xóa cấu hình Entitlements.
* `git push --force`, `git reset --hard`, sửa lịch sử git.
* Cài đặt thêm thư viện thứ ba qua SPM.
* Thao tác I/O ra ngoài thư mục sandbox của app hoặc sửa file hệ thống.

---

# PHẦN I: LÕI KỸ THUẬT NỀN TẢNG (CORE PRINCIPLES)

## ĐIỀU 1: GIỚI HẠN KÍCH THƯỚC TRẦN CỨNG & TÁI SỬ DỤNG
* **Trần cứng file & hàm:**
  * File code: ≤ **300 dòng**.
  * Hàm/Phương thức: ≤ **50 dòng**.
  * SwiftUI View `body`: ≤ **40 dòng**.
  * Lồng khối (nesting): ≤ **3 cấp** (dùng early `guard` để làm phẳng code).
  * Vượt trần: Bắt buộc tách file, tách subview, hoặc tách UseCase. Với code cũ có sẵn vượt trần: báo cáo, không tự ý tách nếu không có lệnh refactor.
* **Quy tắc Tái sử dụng:**
  * **Trước khi viết** helper, modifier, hoặc control mới: tìm trong thư mục `UIComponents/` và `Shared/`.
  * Đã có logic tương đương: dùng lại, cấm tạo bản sao (`.copy()`, `2`).
  * Thay đổi hiện tại cần ở từ 2 nơi trở lên: viết **một lần** ở module dùng chung phù hợp.

## ĐIỀU 2: KHÔNG HARDCODE & QUẢN LÝ STATE
* Không dùng chuỗi/số trôi nổi (magic numbers/strings). Gom vào `enum`, hằng số tĩnh có kiểu (`enum Metric`, `enum AppConstant`).
* Chuỗi hiển thị giao diện Desktop: Dùng `String(localized: ...)` hoặc String Catalog.
* **State cục bộ trước:** Giữ `@State` ở component gần nhất; chỉ nâng lên `@Observable` ViewModel khi có từ 2 component con khác nhánh cần dùng chung.
* **Một nguồn sự thật duy nhất (Single Source of Truth):** Không lưu cùng một dữ liệu ở cả ViewModel và View rồi đồng bộ thủ công. Dữ liệu suy ra được thì dùng computed property.

## ĐIỀU 3: XỬ LÝ LỖI KHÔNG CHE GIẤU (FAIL FAST & LOUD)
* Mọi I/O file, xử lý dữ liệu nặng, mã hóa, network đều phải có xử lý lỗi tường minh.
* **Cấm nuốt lỗi:**
  * **Cấm force unwrap (`!`)** (Ngoại lệ: `@IBOutlet` cũ nếu có, hoặc `fatalError` trong Preview Mock).
  * **Cấm dùng `try?` vô căn cứ** làm biến mất nguyên nhân lỗi mà không log.
* **Chuẩn hóa lỗi hệ thống qua Enum:**
  ```swift
  public enum AppError: LocalizedError, Sendable {
      case fileNotFound(URL)
      case permissionDenied(String)
      case encodingFailed(reason: String)
      case stateCorruption(details: String)

      public var errorDescription: String? { ... }
      public var recoverySuggestion: String? { ... }
  }
  ```

## ĐIỀU 4: BẢO MẬT DESKTOP & DỮ LIỆU NHẠY CẢM
* Mọi API Token, Passwords, Chứng chỉ phải lưu trong **macOS Keychain Services**, tuyệt đối không lưu trong `UserDefaults` hay commit vào git.
* Tuân thủ App Sandbox: Mọi quyền truy cập File bên ngoài sandbox phải thông qua `NSOpenPanel` / `NSSavePanel` và duy trì qua **Security-Scoped Bookmarks**.
* Không ghi log thông tin định danh cá nhân, token, khóa giải mã vào `OSLog`.

---

# PHẦN II: KIẾN TRÚC MÔ-ĐUN HÓA LÕI & BACKEND (SPM ARCHITECTURE)

Dự án desktop phải phân tách thành các module độc lập qua **Local Swift Packages / Targets**.

```
┌────────────────────────────────────────────────────────────────────────┐
│                    App Layer (Composition Root)                        │
│       (@main DesktopApp, WindowGroup, MenuBar, Commands, DI Container) │
└───────────────┬────────────────────────────────────────┬───────────────┘
                │                                        │
                ▼                                        ▼
┌──────────────────────────────┐        ┌────────────────────────────────┐
│       Features Modules       │        │   UIComponents / DesignSystem  │
│ (FeatureEditor, FeatureList) │◄───────┤ (Tokens, Primitives, Controls) │
└───────────────┬──────────────┘        └────────────────────────────────┘
                │
                ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        Domain Module (Pure Swift)                      │
│        (Entities, Use Cases, Value Types, Repository Protocols)        │
└────────────────────────────────┬───────────────────────────────────────┘
                                 ▲
                                 │ implements protocol
┌────────────────────────────────┴───────────────────────────────────────┐
│                     Infrastructure / Data Module                       │
│        (File System, SwiftData/GRDB, URLSession, SecurityBookmarks)    │
└────────────────────────────────────────────────────────────────────────┘
```

## ĐIỀU 5: NGUYÊN TẮC PHỤ THUỘC MỘT CHIỀU (DEPENDENCY INVERSION)
1. **Domain là Pure Swift:**
   * Target `Domain` chỉ import `Foundation`.
   * **CẤM TUYỆT ĐỐI:** `import SwiftUI`, `import AppKit`, hay các database ORM (`SwiftData`, `CoreData`, `GRDB`) vào `Domain`.
2. **Protocol tại Domain, Implementation tại Infrastructure:**
   * Mọi giao tiếp ra thế giới bên ngoài (đọc ghi file, database, network) đều khai báo bằng `protocol` đặt trong `Domain`.
   * Ví dụ:
     ```swift
     // Trong Domain/Repositories/ProjectRepositoryProtocol.swift
     public protocol ProjectRepositoryProtocol: Sendable {
         func loadProject(from url: URL) async throws -> ProjectEntity
         func saveProject(_ project: ProjectEntity, to url: URL) async throws
     }
     ```
   * Target `Infrastructure` chịu trách nhiệm implement protocol này.
3. **Features không import Infrastructure:**
   * Feature chỉ biết `Domain` và `UIComponents`.
   * Feature nhận các concrete implementation thông qua Protocol Injection do tầng `App` truyền vào.
4. **Feature không import Feature khác:**
   * Hai module Feature không được import lẫn nhau. Mọi giao tiếp liên Feature phải đi qua Domain (Command, Event stream, hoặc Navigation Coordinator ở tầng App).

## ĐIỀU 6: SWIFT 6 STRICT CONCURRENCY & AN TOÀN BỘ NHỚ
1. **Sendable Enforcement:** Mọi Entity, Command, Value Type đi qua ranh giới giữa các module/thread bắt buộc phải conform `Sendable`.
2. **Phân định rõ Actor Isolation:**
   * Toàn bộ ViewModel, Screen State, Navigation Coordinator phải đánh dấu `@MainActor`.
   * Các tác vụ nặng (Xử lý ảnh/video, Parse JSON lớn, Mã hóa, Đọc/ghi disk) phải được bọc trong `actor` độc lập hoặc chạy qua `Task.detached(priority: .userInitiated)`. Tuyệt đối không làm đơ Main Thread (cấm drop frame, cấm quay con trỏ chuột).
3. **Quản lý Vòng đời & Bộ nhớ Cửa sổ Desktop:**
   * Sử dụng `[weak self]` trong closures bất đồng bộ và Combine publishers.
   * Cửa sổ Desktop macOS (`WindowGroup` / `NSWindow`) có thể mở và đóng liên tục. Khi cửa sổ đóng, toàn bộ ViewModel và bộ nhớ đệm của cửa sổ đó phải được giải phóng hoàn toàn.

---

# PHẦN III: QUY CHUẨN COMPONENT HÓA FRONTEND MACOS & CÁC CẤP ĐỘ GIỚI HẠN

Để đảm bảo UI tái sử dụng tối đa nhưng **không rơi vào bẫy "Over-abstraction" (tách vụn vặt gây khó đọc)**, hệ thống giao diện macOS tuân thủ **4 cấp độ nghiêm ngặt có giới hạn trần**.

```
[ Cấp 0: Tokens & Primitives ]  ──► Thuần visual/style, không nghiệp vụ
              ▼
[ Cấp 1: Generic Controls ]     ──► Reusable toàn app, nhận Props/Binding thuần
              ▼
[ Cấp 2: Domain Organisms ]     ──► Gắn với Domain Entity/Protocol, không gọi I/O
              ▼
[ Cấp 3: Screen / Window / Page]──► Nhúng ViewModel, xử lý Window, phím tắt & I/O
```

## ĐIỀU 7: ĐẶC TẢ 4 CẤP ĐỘ COMPONENT FRONTEND

### CẤP 0: DESIGN TOKENS & PRIMITIVES (Gốc giao diện)
* **Trách nhiệm:** Màu sắc ngữ cảnh (Semantic Colors), Typography, Spacing, Visual Effects (Translucency/Vibrancy của macOS), AppKit Native View Wrappers nguyên thủy (`NSViewRepresentable`).
* **Vị trí:** `UIComponents/Tokens/` hoặc `UIComponents/Primitives/`.
* **Quy chuẩn:** Khai báo qua Extension, `ViewModifier`, hoặc Struct tĩnh.
* **Giới hạn cấm:** Cấm chứa logic nghiệp vụ; cấm biết đến bất kỳ Model/Entity nào của Domain.

### CẤP 1: GENERIC CONTROLS & MOLECULES (Thành phần dùng chung toàn app)
* **Trách nhiệm:** Các nút điều khiển desktop nâng cao: `CustomSearchField`, `SliderWithScrubber`, `StatusBadge`, `MetricChip`, `SegmentedToolbarItem`, `CustomSplitDivider`.
* **Vị trí:** `UIComponents/Controls/`.
* **Quy chuẩn:**
  * Chỉ nhận input qua kiểu dữ liệu nguyên thủy (`String`, `Double`, `Bool`, `Image`) hoặc `@Binding`.
  * Giao tiếp ra ngoài hoàn toàn qua closures (`onCommit`, `onValueChanged`, `onTap`).
* **Giới hạn cấm:** Cấm import `Domain`; cấm gắn chặt với bất kỳ nghiệp vụ cụ thể nào; cấm chứa `@StateObject` / `@Observable` ViewModel nghiệp vụ.

### CẤP 2: DOMAIN ORGANISMS & COMPOSITE BLOCKS (Khối giao diện nghiệp vụ)
* **Trách nhiệm:** Các khối phức hợp hiển thị và tương tác với dữ liệu miền: `ProjectRowView`, `InspectorPropertySection`, `LayersListTable`, `MediaPreviewBox`.
* **Vị trí:** `Features/<FeatureName>/Components/`.
* **Quy chuẩn:**
  * Nhận dữ liệu thông qua **Domain Entity (Value Type/Struct)** hoặc **Display Protocol**.
  * Nhận các action closure để báo cho tầng trên (ví dụ: `onDelete: () -> Void`, `onRename: (String) -> Void`).
* **Giới hạn cấm:**
  * Không tự khởi tạo ViewModel nội bộ.
  * Không tự gọi Service, Repository hay Database từ Cấp 2. Cấm viết `Task { await repo.fetch() }` bên trong Organism.

### CẤP 3: SCREENS, WINDOWS & SHEETS (Tầng lắp ghép & Điều phối)
* **Trách nhiệm:** Quản lý toàn bộ vòng đời cửa sổ macOS (`WindowGroup`, `DocumentWindow`, `SettingsScene`, `Sheet`, `InspectorSheet`).
* **Vị trí:** `Features/<FeatureName>/Screens/`.
* **Quy chuẩn:**
  * Nơi duy nhất được phép khởi tạo và sở hữu **ViewModel** (`@StateObject` hoặc `@Observable`).
  * Lắp ghép các Component Cấp 0, 1, 2 thành giao diện hoàn chỉnh.
  * Quản lý Toolbar (`.toolbar`), phím tắt (`.keyboardShortcut`), MenuBar commands, và điều hướng (`NavigationSplitView`).
* **Giới hạn cấm:** Cấp 3 không tự vẽ các thành phần đồ họa nhỏ (nút bấm, badge, icon style) mà phải tái sử dụng từ Cấp 0 và Cấp 1.

## ĐIỀU 8: LUẬT PHÒNG CHỐNG TRỪU TƯỢNG HÓA THÁI QUÁ (ANTI-OVERENGINEERING)
1. **Luật "Dùng 3 lần" (Rule of Three):** Không tách một view thành Component Cấp 1 trừ khi nó thực sự được dùng ở ít nhất 2 màn hình khác nhau hoặc phục vụ hệ thống Design System chung của app.
2. **Cấm Single-Use Wrapper:** Cấm tạo một struct View mới chỉ để bọc một SwiftUI view có sẵn mà không thêm style, accessibility hoặc logic tương tác (ví dụ: cấm tạo `CustomVStack` chỉ để bọc `VStack(spacing: 12)`).
3. **Giới hạn lồng cấp tối đa:** Một cây giao diện không được lồng sâu quá **4 tầng component**:
   `Cấp 3 (Screen) → Cấp 2 (Organism) → Cấp 1 (Control) → Cấp 0 (Primitive)`. Cấm chèn thêm tầng trung gian vô nghĩa.
4. **Phân tách State theo tần số cập nhật (High vs Low Frequency):**
   * **State tần số cao (60/120Hz):** Vị trí con trỏ chuột, dragging frame, timeline scrub position, audio VU meter. Phải tách vào object/view con riêng biệt.
   * **State tần số thấp:** Metadata dự án, danh sách layer, thuộc tính cài đặt.
   * Cấm đặt state tần số cao chung một `@Observable` với state tần số thấp, tránh làm re-render toàn bộ màn hình khi người dùng di chuột.

---

# PHẦN IV: HỆ THỐNG GIAO DIỆN CHUNG & TESTABILITY QUA PROTOCOL

## ĐIỀU 9: CHUẨN HÓA VIEW STATE (GIAO DIỆN TRẠNG THÁI HIỂN THỊ)
Mọi Screen (Cấp 3) hoặc Organism phức tạp (Cấp 2) có trạng thái bất đồng bộ phải sử dụng enum chuẩn hóa:

```swift
public enum ViewState<T: Sendable>: Sendable {
    case idle
    case loading(message: String?)
    case success(T)
    case empty(title: String, description: String?, systemImage: String?)
    case failure(AppError)
}
```

## ĐIỀU 10: QUY CHUẨN PROTOCOL-FIRST CHO VIEWMODEL & PREVIEW-FIRST
1. **Mọi ViewModel có Protocol:**
   ```swift
   @MainActor
   public protocol ProjectEditorViewModelProtocol: ObservableObject {
       var state: ViewState<ProjectDetails> { get }
       var isSaving: Bool { get }
       func save() async
       func export(to url: URL) async throws
   }
   ```
2. **Bắt buộc có Mock ViewModel:** Mọi ViewModel Protocol phải có một `Mock...ViewModel` đi kèm.
3. **100% Offline Previews:** Tất cả SwiftUI Previews phải chạy bằng Mock, render ngay lập tức, không phụ thuộc vào network hay file thật trên disk.

## ĐIỀU 11: MÔ HÌNH COMMAND PATTERN CHO THAO TÁC NGHIỆP VỤ (UNDO/REDO)
* Mọi hành động sửa đổi dữ liệu miền của người dùng (Thêm/Sửa/Xóa item, Đổi thông số, Di chuyển vị trí) phải được mô hình hóa thành một `Command` bất biến trong `Domain`.
* **Một nguồn sự thật cho Undo/Redo:** Sử dụng `UndoStack` tự xây dựng trong `Domain`. Menu `Edit → Undo / Redo` của macOS chỉ gọi vào hàm `session.undo()` / `session.redo()`, tuyệt đối không dùng song song `NSUndoManager` làm nguồn sự thật thứ hai.

---

# PHẦN V: ĐẶC THÙ DESKTOP MACOS NATIVE

## ĐIỀU 12: QUẢN LÝ CỬA SỔ & MENU COMMANDS
1. **Window Identifiers rõ ràng:** Mọi cửa sổ (`WindowGroup`, `Settings`, `Window`) phải có `id` cố định.
2. **Menu Commands & Shortcuts:**
   * Tập trung hóa khai báo phím tắt vào `Commands` module.
   * Không chiếm dụng các phím tắt tiêu chuẩn của hệ điều hành macOS (Cmd+Q, Cmd+W, Cmd+H, Cmd+M, Cmd+,).
3. **State Restoration:** Khôi phục kích thước và vị trí cửa sổ qua `@SceneStorage` hoặc NSWindow autosave name.

## ĐIỀU 13: APP SANDBOX & SECURITY-SCOPED BOOKMARKS
1. Mọi truy cập vào file bên ngoài sandbox của ứng dụng phải lấy qua `NSOpenPanel` hoặc `NSSavePanel`.
2. Khi mở file/thư mục, ứng dụng phải lưu lại `bookmarkData` với cờ `withSecurityScope: true`.
3. Khi truy cập lại file từ bookmark, bắt buộc bọc trong:
   ```swift
   guard url.startAccessingSecurityScopedResource() else { throw AppError.permissionDenied(...) }
   defer { url.stopAccessingSecurityScopedResource() }
   // Thực hiện I/O
   ```

---

# PHẦN VI: BỘ CÔNG CỤ ÉP BUỘC KỶ LUẬT (CI & LINTING)

1. **SwiftLint Cưỡng chế:**
   * Giới hạn file: Cảnh báo ở 200 dòng, Lỗi ở 300 dòng.
   * Giới hạn hàm: Cảnh báo ở 40 dòng, Lỗi ở 50 dòng.
   * Cấm `force_cast`, `force_try`, `force_unwrapping`.
2. **Build Flags Bắt buộc:**
   * `-strict-concurrency=complete`
   * `-warn-concurrency`
3. **Định nghĩa "Xong" (Definition of Done - DoD):**
   Một nhiệm vụ của Agent chỉ được coi là hoàn tất khi:
   - [ ] Build thành công không có Warning mới (`swift build`).
   - [ ] Unit Test liên quan chạy qua 100% (`swift test`).
   - [ ] Không có file mới nào vượt trần 300 dòng hoặc hàm vượt 50 dòng.
   - [ ] Báo cáo đúng định dạng Phụ lục B kèm **output nguyên văn của lệnh build/test**.

---

# PHỤ LỤC A: MẪU PACKAGE.SWIFT MÔ-ĐUN HÓA CHUẨN

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DesktopCore",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Infrastructure", targets: ["Infrastructure"]),
        .library(name: "UIComponents", targets: ["UIComponents"]),
        .library(name: "FeatureEditor", targets: ["FeatureEditor"]),
    ],
    dependencies: [],
    targets: [
        // 1. Pure Swift Domain
        .target(
            name: "Domain",
            dependencies: [],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(name: "DomainTests", dependencies: ["Domain"]),

        // 2. Infrastructure (Implements Domain Protocols)
        .target(
            name: "Infrastructure",
            dependencies: ["Domain"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(name: "InfrastructureTests", dependencies: ["Infrastructure"]),

        // 3. UI Components (Level 0 & 1 - Design System)
        .target(
            name: "UIComponents",
            dependencies: [],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),

        // 4. Feature Module (Level 2 & 3)
        .target(
            name: "FeatureEditor",
            dependencies: ["Domain", "UIComponents"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(name: "FeatureEditorTests", dependencies: ["FeatureEditor"]),
    ]
)
```

---

# PHỤ LỤC B: MẪU BÁO CÁO CÔNG VIỆC CỦA AGENT (REPORT TEMPLATE)

Agent sau khi hoàn thành nhiệm vụ bắt buộc phải báo cáo theo định dạng sau:

```markdown
### 1. ĐÃ THỰC HIỆN
- [x] Mô tả thay đổi: [Mô tả ngắn gọn tính năng hoặc sửa lỗi]
- [x] Danh sách file đã sửa đổi / tạo mới:
  - `Modules/UIComponents/Controls/SearchField.swift` (Cấp 1)
  - `Modules/Features/FeatureEditor/Components/DocumentRowView.swift` (Cấp 2)
  - `Modules/Features/FeatureEditor/Screens/EditorScreen.swift` (Cấp 3)
- [x] Kiểm tra trần kích thước: File lớn nhất: 142 dòng (<= 300), Hàm dài nhất: 28 dòng (<= 50).

### 2. KẾT QUẢ KIỂM CHỨNG THỰC TẾ (VERIFICATION OUTPUT)
Lệnh đã chạy: `swift test`
Output nguyên văn từ terminal:
```text
Test Suite 'All tests' passed at 2026-11-01 13:50:00.000.
	 Executed 14 tests, with 0 failures (0 unexpected) in 0.412 seconds.
Build complete! (0 warnings, 0 errors)
```

### 3. VI PHẠM TỒN ĐỌNG PHÁT HIỆN ĐƯỢC (NẾU CÓ)
- [Phát hiện nhưng chưa sửa vì nằm ngoài phạm vi task]: File `LegacyBridge.swift` đang dài 340 dòng và dùng force unwrap.

### 4. RỦI RO & BƯỚC TIẾP THEO CẦN NGƯỜI DÙNG DUYỆT
- Cần người dùng xác nhận cấp thêm Entitlement `com.apple.security.files.user-selected.read-write` trong Xcode nếu build bản release.
```
