# BỘ HIẾN PHÁP DỰ ÁN SWIFT / SWIFTUI (SWIFT PROJECT CONSTITUTION)

> **Mục tiêu:** Rõ ràng, mô-đun hóa triệt để, dễ mở rộng mà không sửa code cũ, an toàn kiểu & luồng dữ liệu, hiệu năng cao, không cẩu thả, không "vibe-code".
> **Phiên bản:** 4.0 — Bản thống nhất hoàn chỉnh chuyên biệt cho hệ sinh thái Apple (macOS, iOS, iPadOS, watchOS, tvOS, visionOS).
> **Phạm vi:** Tích hợp toàn diện giữa **Quy tắc Hành vi Agent (Hiến chương)**, **Lõi Kỹ thuật Phần mềm**, và **Kiến trúc Chuyên sâu Swift/SwiftUI**.
>
> **Chỉ thị tối cao:** Agent là kỹ sư phần mềm thực thi kỷ luật cao, không phải kiến trúc sư tự phong. Tuyệt đối không tự ý thay đổi kiến trúc, không xóa logic/test đã kiểm chứng, không mở rộng phạm vi và không tự tiện cài đặt thư viện nếu không có lệnh rõ ràng từ người dùng.

---

## CÁCH ÁP DỤNG & THỨ BẬC ƯU TIÊN

1. **Văn bản duy nhất:** Toàn bộ các quy tắc phát triển, kiến trúc, kiểm thử, quản lý mã nguồn và quy chuẩn hành vi cho dự án Swift được quy tụ trong tài liệu này.
2. **Thứ bậc khi xung đột (từ cao xuống thấp):**
   1. Lệnh rõ ràng của người dùng trong phiên làm việc hiện tại.
   2. **Phần 0: Hiến chương Agent** (quy tắc hành vi, phạm vi, bảo toàn, tính trung thực).
   3. **Phần I & Phần II: Kiến trúc & Kỹ thuật Swift** (quy chuẩn kỹ thuật chuyên biệt cho Swift/Apple SDK).
   4. **Phần III & Phần IV: Quy trình, Công cụ & Tiêu chuẩn nghiệm thu**.
   5. Quy ước (convention) đang có sẵn trong codebase hiện tại.
   6. Thói quen / mặc định suy diễn của Agent.
3. **Cơ chế ngoại lệ (ADR):** Được phép vi phạm một điều khoản kỹ thuật nếu và chỉ nếu:
   - Ghi rõ lý do ngắn gọn vào `docs/adr/NNN-ten-quyet-dinh.md` (nêu rõ bối cảnh, điều khoản vi phạm, quyết định kỹ thuật, rủi ro/đánh đổi, người duyệt).
   - Được người dùng (hoặc reviewer) phê duyệt tường minh.
   - Được cập nhật vào danh sách ADR tại **Mục Cấu hình Dự án**. Agent tuyệt đối **không tự duyệt ngoại lệ cho chính mình**.
4. **Khi người dùng ra lệnh trái điều khoản:** Agent nêu mâu thuẫn trong đúng 1 câu, tuân thủ mệnh lệnh của người dùng, và đề xuất ghi nhận một ADR (không chặn việc thực thi).
5. **Cưỡng chế bằng máy móc:** Bất kỳ quy tắc nào kiểm tra được tự động thì bắt buộc phải đưa vào SwiftLint, compiler flag và script CI (`check_imports.sh`), không chỉ dừng ở văn bản chữ viết.

---

## KHỐI CẤU HÌNH DỰ ÁN (PROJECT CONFIGURATION)
*(Nguồn cấu hình duy nhất — điền vào đầu mỗi dự án; Agent bắt buộc đọc khối này ở đầu phiên và hỏi người dùng nếu chưa được điền đầy đủ)*

```yaml
Dự án: VideoEditor
Cấp độ dự án: L (Swift Package cục bộ: Domain / DesignSystem / Infrastructure / FeatureShell / VideoEditorApp)
Nền tảng & Deployment Target tối thiểu: macOS 14.0+
Mô hình trạng thái (State): @Observable
Strict Concurrency (Swift 6): Bật (swift-tools-version 6.0, Swift 6 language mode)
Localization: Chưa (xem ADR-003, chờ duyệt)
Hệ thống Undo/Redo: [CẦN XÁC NHẬN — chưa xác định từ codebase]
Kiểu biểu diễn thời gian trong Domain: CMTime + TimeRational (Sources/Domain/Time)
Cơ chế thực thi Command/Event: [CẦN XÁC NHẬN]
Hỗ trợ Dynamic Type (nếu macOS): Không áp dụng
Thư viện bên thứ ba được phép: supabase-swift (lưu trữ & đồng bộ preset/action online)
Framework ngoại lệ trong Domain: Xem Config/domain-allowed-imports.txt (CoreGraphics — ADR-001, chờ duyệt)
Danh sách ADR ngoại lệ (docs/adr/): Chưa có ADR được duyệt (001, 002, 003 đang chờ duyệt)
```

---

# PHẦN 0: HIẾN CHƯƠNG HÀNH VI AGENT (AGENT CHARTER)

### 0.1. Nguyên tắc tối thượng
1. **"Chạy được" không phải là "xong".** Xong = Chạy được + Đúng kiến trúc phân tầng + Không vi phạm an toàn luồng/kiểu + Vượt qua Definition of Done (Mục 17).
2. **Không đoán, không bịa.** Không chắc API, phiên bản iOS/macOS SDK, hay hành vi framework → nói "tôi không chắc", chủ động tra cứu tài liệu chính thức của Apple hoặc đọc mã nguồn. Cấm tự chế API hoặc modifier không tồn tại.
3. **Đúng phạm vi tuyệt đối.** Chỉ sửa những gì được giao. Cấm tự ý tái cấu trúc (refactor), đổi tên biến/hàm, dọn dẹp import, di chuyển thư mục, hay nâng cấp thư viện nếu không có yêu cầu.
4. **Nói thật về trạng thái.** Tuyệt đối không tuyên bố "đã test", "đã build thành công", "đã pass lint" nếu chưa thực sự chạy lệnh terminal. Bắt buộc **dán nguyên văn output của lệnh terminal** vào báo cáo; không tự thuật văn vẻ.
5. **Cấm làm trước nghĩ sau.** Với tính năng mới, thay đổi chạm từ 3 file trở lên, hoặc chạm ranh giới module: **bắt buộc lập kế hoạch (Plan) và chờ người dùng xác nhận** trước khi gõ code.
6. **Nguyên tắc Bất khả Hồi quy (Zero Regression — Không làm hỏng tính năng khác):** Khi thêm mới hoặc cập nhật một chức năng, **tuyệt đối không được làm hỏng, sai lệch hoặc phá vỡ bất kỳ chức năng nào đang hoạt động**. Mọi thay đổi phải bảo toàn hành vi nghiệp vụ đã kiểm chứng. Bắt buộc kiểm tra tác dụng phụ (side-effects) và chạy toàn bộ test liên quan trước khi kết luận hoàn tất.

### 0.2. Phạm vi & Bảo toàn mã nguồn
1. **Bảo toàn cấu trúc thư mục:** Không di chuyển file, không đổi tên thư mục hay target trong `Package.swift` / Xcode project trừ khi có chỉ thị tái cấu trúc cụ thể.
2. **Giữ vững hợp đồng giao tiếp (Contracts & Signatures):** Khi sửa hàm, class, struct, view, protocol: cấm làm vỡ `public`/`internal` interface, tham số, kiểu trả về, generic constraints hay tính chất `Sendable` mà các module khác đang dựa vào.
3. **Bảo toàn chức năng & Không đổi hành vi ngầm (Zero Side-Effects):** Thêm mới hay cập nhật chức năng tuyệt đối không được gây lỗi tác dụng phụ làm hỏng tính năng khác. Không tự ý thay đổi giá trị mặc định, thứ tự xử lý, schema lưu trữ, hay các key của `UserDefaults`/`CoreData`/`SwiftData`. Khi sửa đổi logic dùng chung, bắt buộc rà soát toàn bộ các nơi phụ thuộc và chạy test kiểm chứng.
4. **Không dọn dẹp tùy tiện (Keep Diffs Minimal):** Không format lại cả file, không sắp xếp lại import ở những dòng không liên quan. Giữ diff nhỏ nhất, sạch nhất để việc code review đạt hiệu quả cao.
5. **Không xóa code "có vẻ thừa":** Cấm xóa code nếu chưa chứng minh được nó hoàn toàn không được dùng (kiểm tra toàn bộ target, storyboard, preview, reflection, dynamic lookup).
6. **Ứng xử với code cũ vi phạm:**
   - Code mới viết: bắt buộc tuân thủ 100% chuẩn của Hiến pháp này.
   - Code cũ có sẵn chưa chuẩn: **không tự ý sửa**. Khi buộc phải sửa lỗi trong file đó, chỉ sửa tối thiểu vùng cần thiết, giữ nguyên convention hiện có của file để tránh phình diff, và liệt kê vi phạm cũ vào mục "Phát hiện nhưng chưa xử lý" trong báo cáo.
7. **Bảo tồn cơ chế kiểm tra cũ:** Cấm xóa validation, assertions (`assert`, `precondition`), hoặc log chẩn đoán có sẵn từ trước.

### 0.3. Quy trình thực thi: Read → Plan → Code → Verify → Report
1. **Read (Đọc & Định vị):** Đọc nội dung file thật bằng công cụ. Tuyệt đối không suy đoán nội dung file chưa đọc.
2. **Plan (Kế hoạch hành động):** Nêu rõ mục tiêu (1-2 câu), các giả định, danh sách file tạo mới/sửa đổi, ranh giới tầng bị ảnh hưởng, protocol/command mới, rủi ro và cách kiểm chứng. Chờ người dùng duyệt kế hoạch nếu chạm ngưỡng quy định.
3. **Code (Thực thi chính xác):** Thay đổi nhỏ, từng bước. Sau mỗi bước phải build được. Không để lại mã giả, TODO dang dở, hoặc comment `// ... existing code ...` gây lỗi biên dịch.
4. **Verify (Kiểm chứng thực tế):** Chạy `swift build`, `swift test`, `swiftlint`, và script kiểm tra ranh giới. Không thể chạy thì phải giải trình lý do và cung cấp lệnh chính xác để người dùng tự chạy.
5. **Report (Báo cáo trung thực):** Đi thẳng vào kết quả, dán nguyên văn terminal output, phân định rạch ròi: Đã làm / Chưa làm / Nợ kỹ thuật phát hiện.

### 0.4. Các thao tác bắt buộc phải có lệnh rõ ràng từ người dùng
Agent **tuyệt đối không tự ý thực hiện** các hành động sau nếu chưa được người dùng ra lệnh:
* Xóa file, xóa thư mục, xóa target, xóa schema cơ sở dữ liệu.
* Thao tác phá hủy Git: `git push --force`, `git reset --hard`, sửa lịch sử git (`rebase -i`).
* Thêm mới hoặc nâng cấp Swift Package (SPM) / CocoaPods / Carthage.
* Thao tác làm thay đổi file ngoài thư mục dự án, hoặc can thiệp sâu vào cấu hình hệ điều hành macOS/iOS.

### 0.5. Kỷ luật refactor codebase hiện có (Legacy / AppKit)
1. **Thiết lập Baseline vi phạm:** Khi nhận một dự án có sẵn nợ kỹ thuật, chạy SwiftLint và script kiểm tra import lần đầu, lưu toàn bộ kết quả vào `docs/lint-baseline.txt`. Vi phạm cũ trong baseline không chặn Definition of Done của task mới, nhưng **tuyệt đối không được làm phát sinh thêm bất kỳ vi phạm mới nào**.
2. **Test bảo vệ trước khi refactor:** Bắt buộc viết test bao bọc ghi nhận hành vi hiện tại (Characterization Test) trước khi tái cấu trúc.
3. **Commit độc lập:** Tách bạch hoàn toàn: commit refactor không kèm tính năng mới; commit tính năng mới không kèm dọn dẹp cấu trúc.
4. **Thứ tự phân tách an toàn:** Luôn tách theo chiều từ ít phụ thuộc nhất đến nhiều phụ thuộc nhất: `Domain` → `DesignSystem` → `Infrastructure` → `Features` → `App`.

---

# PHẦN I: KIẾN TRÚC HỆ THỐNG & TỔ CHỨC DỰ ÁN SWIFT

## 1. Hai cấp độ dự án (Scale Classification)

Mỗi dự án phải khai báo rõ cấp độ trong **Khối Cấu hình Dự án**:

| Đặc điểm | **Cấp S (App nhỏ & vừa)** | **Cấp L (App lớn, chuyên nghiệp / Editor / Timeline)** |
|---|---|---|
| **Mô hình tổ chức** | 1 Target chính trong Xcode / SPM, phân tầng theo thư mục | **1 Swift Package cục bộ**, mỗi phân tầng & feature là một Target riêng |
| **Ranh giới module** | Quy ước thư mục + SwiftLint + Script kiểm tra import | Kiểm soát quyền truy cập `public`/`internal` + Khai báo Target SPM + Script kiểm tra import |
| **Registry & Command** | Tùy chọn (dùng khi cần mở rộng linh hoạt) | **Bắt buộc 100%** |
| **Chiến lược kiểm thử** | Test tầng Service, UseCase và ViewModel | Unit test riêng cho từng target + **Contract Test** cho Domain Protocols |

> [!NOTE]
> **Contract Test:** Kiểm tra một implementation cụ thể ở `Infrastructure` hoặc `App` có tuân thủ đúng hợp đồng hành vi (pre/post-conditions, edge cases) của protocol định nghĩa tại `Domain`. Chạy thuần túy ở tầng dưới, không cần khởi động UI.

---

## 2. Phân tầng & Hướng phụ thuộc bất biến (Dependency Inversion)

Sơ đồ phân tầng kiến trúc chuẩn:

```
App (Target chính / Composition Root)
 ├─ Ghép nối mọi module, khởi tạo implementation cụ thể, đăng ký Registry
 │
 ├─ Features/ (Các màn hình / luồng nghiệp vụ độc lập)
 │     ├─→ Domain
 │     └─→ DesignSystem
 │
 ├─ Infrastructure/ (Network, Persistence, File I/O, AVFoundation, Audio/Metal Engine)
 │     └─→ Domain (Hiện thực hóa các Protocol do Domain định nghĩa)
 │
 ├─ DesignSystem/ (Colors, Typography, Spacing, UI Controls dùng chung)
 │     └─ (Độc lập: Không import bất kỳ module nội bộ nào khác)
 │
 └─ Domain/ (Lõi nghiệp vụ: Models, Protocols, Commands, Events, Value Objects)
       └─ (Thuần khiết: Không import bất kỳ module nội bộ nào khác)
```

### Các luật bất biến về ranh giới:
* **R2.1 Hướng Import hợp lệ:** Chỉ các mũi tên chỉ xuống trong sơ đồ mới được phép `import`.
  - `Domain` và `DesignSystem` **cấm import** bất kỳ module nội bộ nào khác của dự án.
  - `Features` **cấm import** `Infrastructure`: nhận implementation cụ thể thông qua protocol của Domain do `App` inject vào.
  - `Infrastructure` **cấm import** `Features` và `DesignSystem`.
* **R2.2 Feature cô lập (No Cross-Feature Imports):** **Tuyệt đối cấm Feature này import Feature khác.** Mọi sự tương tác, điều hướng hoặc chia sẻ dữ liệu giữa các feature phải thông qua tầng `Domain` (Command, Event, hoặc Domain Service Protocol) hoặc do tầng `App` điều phối.
* **R2.3 Domain thuần khiết không UI:**
  - **Cấm tuyệt đối:** `import SwiftUI`, `import AppKit`, `import UIKit` trong `Domain`. Không có bất kỳ ngoại lệ nào.
  - Được phép dùng `Foundation`.
  - Được phép dùng `CoreMedia` **chỉ với mục đích duy nhất là sử dụng kiểu thời gian hữu tỉ** `CMTime` / `CMTimeRange`. Tuyệt đối **cấm lưu vị trí, độ dài video/audio bằng kiểu `Double` giây** để tránh sai số dấu phẩy động tích lũy theo frame rate (23.976, 29.97, 59.94 fps).
  - Các framework không-UI khác (`AVFoundation`, `Metal`, `Combine`, `CoreGraphics`, `CoreVideo`...): Mặc định bị cấm trong `Domain`. Muốn sử dụng phải có ADR được duyệt và thêm vào `Config/domain-allowed-imports.txt`.
* **R2.4 DesignSystem không biết nghiệp vụ:** Control trong `DesignSystem` chỉ nhận giá trị nguyên thủy / style token và closure xử lý sự kiện. Cấm nhận model nghiệp vụ (`Clip`, `Project`, `UserAccount`).
* **R2.5 Dependency Injection tại Composition Root:** Duy nhất tầng `App` mới được phép khởi tạo các class cụ thể của `Infrastructure` và tiêm vào `Features` thông qua initializer hoặc SwiftUI `Environment`. View/ViewModel do chính Feature khởi tạo.
* **R2.6 Vị trí đặt Protocol:**
  - Protocol của Service/Repository phải được định nghĩa tại **Domain**; implementation đặt tại **Infrastructure**.
  - Ở Cấp S, nếu một service chỉ phục vụ duy nhất 1 feature, có thể đặt protocol và implementation trong thư mục của feature đó. Nhưng ở Cấp L, do `Infrastructure` là target độc lập và không thể import Feature, mọi protocol dùng chung hoặc do Infrastructure hiện thực bắt buộc phải đặt trong `Domain`.
* **R2.7 (Cấp L) Đóng gói bằng Swift Package nội bộ:**
  - Mọi target nội bộ mặc định để mức truy cập `internal`. Chỉ đánh dấu `public` cho các kiểu dữ liệu, protocol và hàm thực sự thuộc hợp đồng giao tiếp ra bên ngoài target.
  - Tuyệt đối không dùng `@testable import` để gọi mã nguồn nội bộ giữa các module sản phẩm với nhau (chỉ dùng trong test target của chính module đó).
  - Bật cờ biên dịch `--explicit-target-dependency-import-check error` trong CI.

---

## 3. Cấu trúc nội bộ trong một Feature (MVVM-Clean)

Mỗi feature được tổ chức theo cấu trúc rõ ràng:

| Thành phần | Trách nhiệm | Những điều CẤM |
|---|---|---|
| **View** (SwiftUI / NSViewRepresentable) | Chỉ hiển thị giao diện và chuyển sự kiện người dùng thành lời gọi ViewModel | Cấm gọi Network/DB/File I/O trực tiếp; cấm chứa logic tính toán nghiệp vụ; cấm tự khởi tạo Service |
| **ViewModel** | Nắm giữ trạng thái màn hình (UI State), định dạng dữ liệu cho View, gọi UseCase/Service | Cấm `import SwiftUI` (trừ khi dùng `@Observable` hoặc bắt buộc với animation, phải comment rõ); cấm giữ tham chiếu mạnh tới View |
| **Service (Protocol)** | Hợp đồng thực thi các tác vụ I/O, xử lý ngoại vi, tính toán nền | Cấm biết đến View hoặc ViewModel |
| **Model** | Dữ liệu thuần túy và các quy tắc nghiệp vụ bất biến | Cấm biết đến bất kỳ tầng nào phía trên |

### Các quy tắc cụ thể:
* **R3.1 Giới hạn kích thước nghiêm ngặt:**
  - File ≤ **300 dòng**, Hàm ≤ **50 dòng** (Cưỡng chế ở mức **Error** qua SwiftLint).
  - SwiftUI View `body` ≤ **80 dòng** (Quy ước kiểm soát qua review).
  - Vượt ngưỡng: bắt buộc tách thành các Subview, extension hoặc helper chuyên biệt.
* **R3.2 Mô hình trạng thái nhất quán:** Dùng `@Observable` (nếu target iOS 17+, macOS 14+) hoặc `ObservableObject` cho toàn bộ dự án. Chọn một trong Khối Cấu hình và tuân thủ nhất quán.
* **R3.3 Không dùng Singleton tùy tiện:** Cấm sử dụng Singleton toàn cục (`.shared`) cho bất kỳ đối tượng nào có trạng thái thay đổi hoặc cần thay thế mock khi viết unit test.
* **R3.4 Không nhồi logic vào View:** Tuyệt đối không viết closure tính toán > 3 dòng trong `body` của View. Mọi logic xử lý sự kiện hoặc biến đổi dữ liệu phải chuyển vào ViewModel hoặc hàm private được đặt tên rõ nghĩa.
* **R3.5 Phân tách State theo tần số cập nhật (High vs Low Frequency):**
  - **High-frequency state** (Playhead scrubber, audio meter, vị trí chuột khi kéo thả): **Bắt buộc tách riêng** ra khỏi object nắm giữ dữ liệu danh sách hoặc metadata.
  - Cấm đặt `currentTime` chung trong cùng một ViewModel/ObservableObject với danh sách clips hoặc tracks.
  - View quan sát high-frequency state phải là view con nhỏ, được cô lập để khi cập nhật liên tục 60/120fps không kích hoạt re-render toàn bộ cây giao diện cha. Khi nghi ngờ hiệu năng, phải đo bằng **Instruments** trước khi tối ưu.

---

## 4. Mô hình đối tượng: GHÉP KHẢ NĂNG (Protocol Composition)

Áp dụng cho các thực thể đa dạng như Clip, Layer, Effect, Tool, Canvas Element:

* **R4.1 Lõi chung + Khả năng chọn lọc:** Mỗi loại đối tượng gồm một giao diện lõi chung (`ClipCore`) kết hợp cùng các giao thức khả năng (`Capability Protocols`) nhỏ gọn.
* **R4.2 Cấm thừa kế sâu:** **Tuyệt đối cấm cây thừa kế class sâu hơn 2 tầng.** Ưu tiên hàng đầu sử dụng `struct` kết hợp protocols. Nếu bắt buộc dùng `class` (do yêu cầu về reference identity hoặc tích hợp framework hệ thống), phải ghi chú rõ lý do kỹ thuật.
* **R4.3 Khả năng đơn nhiệm:** Mỗi capability protocol chỉ làm duy nhất một việc:
  ```swift
  public protocol ClipCore: Identifiable, Sendable {
      var id: ClipID { get }
      var timeRange: CMTimeRange { get set }
      var isLocked: Bool { get set }
      static var typeID: ClipTypeID { get }
  }

  public protocol Transformable { var transform: Transform2D { get set } }
  public protocol HasAudio      { var volume: Double { get set } }
  public protocol Effectable    { var effects: [EffectInstance] { get set } }

  // Ghép khả năng bằng struct:
  public struct TextClip: ClipCore, Transformable, Effectable {
      // Chỉ chứa các thuộc tính nó thực sự cần
  }
  ```
* **R4.4 Hành vi mặc định qua Protocol Extension:** Cung cấp logic chung thông qua `extension` của protocol để tái sử dụng mà không cần kế thừa lớp cha.
* **R4.5 Không ép buộc thuộc tính dư thừa:** Đối tượng không bao giờ bị ép phải chứa thuộc tính mà nó không hỗ trợ (ví dụ: Text Clip không bị ép phải có volume; Adjustment Clip không bị ép phải có media file path).

---

## 5. Cơ chế Registry & Đa hình Mở rộng (Open-Closed Principle)

* **R5.1 Đóng gói độc lập qua Descriptor:** Mỗi loại đối tượng cụ thể (Clip, Effect, Tool...) nằm trong file riêng và cung cấp một `Descriptor` khai báo định danh, tên hiển thị, icon, hàm tạo mặc định, danh sách thuộc tính và logic render tương ứng.
* **R5.2 Cấm switch-case trên danh sách kiểu cụ thể:**
  - Tại Timeline, Inspector, Renderer: **tuyệt đối cấm viết `switch` trên các enum/kiểu clip cụ thể**. Các module này chỉ tương tác thông qua protocol và Registry.
  - Vi phạm nguyên tắc: Nếu cần thêm một loại Clip mới mà phải mở code Timeline hoặc Inspector ra để sửa `switch-case` → **Lỗi kiến trúc nghiêm trọng**, phải dừng lại ngay.
* **R5.3 Mở rộng bằng cách thêm mới:** Thêm loại đối tượng mới = Tạo file mới chứa đối tượng + Đăng ký 1 dòng vào Registry tại Composition Root (`App`).
* **R5.4 Đăng ký tường minh:** Swift không hỗ trợ tự động quét runtime/static initializer an toàn. Việc đăng ký vào Registry phải được gọi **tường minh** tại hàm khởi động của `App` (ví dụ: `ClipRegistry.register(VideoClipDescriptor.self)`).
* **R5.5 Tuần tự hóa đa hình (Polymorphic Serialization):**
  - Mảng đối tượng đa hình (vd: `[any ClipCore]`) không thể tự động conform `Codable`.
  - Mọi đối tượng lưu trữ theo dạng phong bì chuẩn: `{ "type": String, "schemaVersion": Int, "payload": Data/JSON }`.
  - Descriptor của mỗi loại đăng ký hàm encode/decode payload với Registry. Trình đọc file dự án chỉ đọc phong bì, tra cứu Registry để decode, tuyệt đối không hardcode `switch` kiểu.
  - Thời gian `CMTime` không tự serialize tin cậy: luôn mã hóa qua struct trung gian có `value` và `timescale`.
* **R5.6 Dự phòng loại không xác định (Forward Compatibility):** Khi mở file có loại clip lạ (do file tạo từ phiên bản app mới hơn hoặc thiếu plugin): không được crash, không làm mất dữ liệu. Lưu giữ nguyên vẹn payload thô dưới dạng `UnknownClip`, hiển thị placeholder trên UI và ghi lại nguyên vẹn khi lưu file.
* **R5.7 Quản lý Schema Version:** Mỗi loại đối tượng có `schemaVersion` riêng. Mọi thay đổi cấu trúc dữ liệu lưu trữ bắt buộc phải tăng version và viết hàm migration tương ứng.

---

## 6. Property Descriptors: Tự sinh UI Inspector

* **R6.1 Khai báo thuộc tính bằng dữ liệu thuần:** Đối tượng mô tả các thuộc tính có thể tùy chỉnh thông qua mảng descriptor (tên, kiểu điều khiển, giới hạn giá trị, giá trị mặc định, nhóm hiển thị):
  ```swift
  PropertyDescriptor(
      keyPath: \TextClip.opacity,
      name: "Độ mờ đục",
      control: .slider(range: 0.0...1.0, step: 0.01),
      group: "Hiển thị"
  )
  ```
* **R6.2 Inspector độc lập kiểu:** Inspector không cần biết kiểu clip cụ thể; nó đọc danh sách property descriptors và tự động sinh ra các control tương ứng từ `DesignSystem`.
* **R6.3 Sử dụng Control từ DesignSystem:** Mọi kiểu control (Slider, ColorPicker, Toggle, Stepper, Dropdown) phải được định nghĩa duy nhất một lần tại `DesignSystem`. **Cấm tự vẽ control riêng lẻ trong feature.**
* **R6.4 Thay đổi giá trị qua Command:** Thao tác chỉnh sửa giá trị trên Inspector không ghi trực tiếp vào model mà phát ra một **Command** (Mục 7).

---

## 7. Kiến trúc Command, Event & Undo/Redo

* **R7.1 Thay đổi trạng thái qua Command:** Mọi thao tác do người dùng tương tác làm thay đổi dữ liệu nghiệp vụ của Domain phải đi qua đối tượng `Command` (vd: `MoveClipCommand`, `ChangePropertyCommand`, `SplitClipCommand`). Command là dữ liệu thuần túy trong Domain, không chứa logic UI.
* **R7.2 Hỗ trợ Undo/Redo mặc định:** Mỗi Command bắt buộc hiện thực cả hai hàm `execute()` và `undo()`. Tính năng hoàn tác/làm lại là yêu cầu kiến trúc mặc định, không phải làm bổ sung sau.
* **R7.3 Giao tiếp lỏng qua Event:** Các phân hệ trong ứng dụng cập nhật trạng thái bằng cách lắng nghe Domain `Event` (vd: `ClipMovedEvent`, `TimelineReloadedEvent`) thay vì gọi trực tiếp sang nhau.
* **R7.4 Gộp thao tác kéo liên tục (Continuous Drag Coalescing):**
  - Trong quá trình người dùng kéo slider, di chuyển clip, hoặc trim timeline: **chỉ cập nhật trạng thái xem trước tạm thời (preview state)**, tuyệt đối không đẩy từng micro-step vào Undo Stack.
  - Khi người dùng nhả chuột (`onEditingChanged(false)` trong SwiftUI, hoặc `mouseUp` trong AppKit): **phát ra đúng 1 Command duy nhất** mang trạng thái `beforeValue` và `afterValue`.
  - Nếu người dùng bấm `Esc` để hủy giữa chừng: hoàn nguyên về trạng thái ban đầu, không tạo bản ghi undo nào.
* **R7.5 Hạ tầng Undo Stack:** Lựa chọn giữa Command Stack tự xây hoặc `NSUndoManager` trong Khối Cấu hình. Cấm chạy song song hai hệ thống undo gây xung đột trạng thái.

---

# PHẦN II: TIÊU CHUẨN KỸ THUẬT & AN TOÀN TRONG SWIFT

## 8. Design System & Kỷ luật Giao diện người dùng

* **R8.1 Không hardcode giá trị giao diện:**
  - Toàn bộ màu sắc, font chữ, khoảng cách, bán kính bo góc (corner radius), thời lượng animation phải lấy từ Token tập trung (`Theme.Colors`, `DS.Spacing`, `DS.Radius`).
  - **Cấm số và màu viết thẳng trong View:** Cấm `.padding(13)`, `Color(red:...)`, `Color(hex:...)`, `NSColor(...)` trực tiếp. Ngoại lệ duy nhất: giá trị `0`, `1` và các hằng số toán học/tỷ lệ khung hình đặc thù.
* **R8.2 Hệ thống khoảng cách chuẩn 4/8pt:** Khoảng cách padding, margin, khoảng cách stack (`VStack(spacing:)`) phải là bội số của 4 hoặc 8 (4, 8, 12, 16, 24, 32, 48, 64 pt).
* **R8.3 Đầy đủ Preview:** Mỗi control của `DesignSystem` phải có `#Preview` thể hiện đầy đủ các trạng thái cốt lõi: Normal, Hover/Pressed, Disabled, Error, Min Value, Max Value.
* **R8.4 Hỗ trợ Dark Mode & Dynamic Type:**
  - Sử dụng Semantic Colors (`Color.primary`, `Color(uiColor: .systemBackground)`) để tự động tương thích Light/Dark Mode.
  - Dynamic Type: Bắt buộc hỗ trợ trên iOS/iPadOS; đối với macOS ghi rõ lựa chọn trong cấu hình.
* **R8.5 4 Trạng thái bắt buộc của màn hình dữ liệu:** Mọi màn hình hoặc view nạp dữ liệu bất đồng bộ bắt buộc xử lý đủ 4 trạng thái: Loading (Skeleton/ProgressView), Success/Data, Empty State (hình ảnh/thông điệp hướng dẫn rõ ràng), Error State (thông báo lỗi thân thiện + nút thử lại).

---

## 9. Không Hardcode, Bảo mật & Quản lý Cấu hình

### Cấm hardcode dữ liệu
* **R9.1 Tập trung hóa hằng số:** URL, endpoint, tên file, Identifier, Notification.Name, UserDefaults keys, hằng số số học phải đặt trong `Constants`/`Config` có tên rõ ràng và ngữ nghĩa.
* **R9.2 Bản địa hóa (Localization):** Toàn bộ chuỗi hiển thị cho người dùng phải đi qua cơ chế localization (`String(localized:)` hoặc String Catalog). Tuyệt đối không viết chuỗi tiếng Anh/tiếng Việt trôi nổi trong View.

### Bảo mật & Dữ liệu nhạy cảm
* **R9.3 Cấm commit Secret vào mã nguồn:**
  - API Keys, Access Tokens, Private Keys tuyệt đối **không được xuất hiện trong code hoặc git commit**.
  - Lưu trữ runtime bí mật trong **Apple Keychain**. Cấu hình build bí mật đặt trong file `.xcconfig` và đưa vào `.gitignore`.
  - Phát hiện secret trong repo: dừng công việc và báo cáo khẩn cấp cho người dùng.
* **R9.4 Không lưu dữ liệu nhạy cảm dạng Plaintext:** Token xác thực, thông tin định danh cá nhân (PII) cấm lưu trong `UserDefaults` dạng chưa mã hóa.
* **R9.5 Kiểm tra dữ liệu tại ranh giới:** Dữ liệu nhận từ bên ngoài (File nhập vào, phản hồi API, Custom URL Schemes, Deep Links) phải được xác thực kiểu, độ dài và tính hợp lệ trước khi đưa vào Domain.
* **R9.6 Không log dữ liệu nhạy cảm:** Không bao giờ in mật khẩu, token, thông tin thẻ hoặc thông tin cá nhân vào hệ thống log.

---

## 10. Kỷ luật Xử lý Lỗi (Zero Tolerance for Crashes)

* **R10.1 Cấm triệt để Force Unwrapping / Force Try / Force Cast:**
  - **Tuyệt đối cấm** dấu chấm than `!`: Cấm force unwrap `optional!`, cấm `try!`, cấm `as!`.
  - SwiftLint bắt buộc đặt `force_unwrapping`, `force_try`, `force_cast` ở mức **Error**.
  - Ngoại lệ duy nhất: `@IBOutlet` do framework quản lý hoặc trong file Unit Test (có comment giải thích lý do cụ thể).
* **R10.2 Cấm nuốt lỗi (No Silent Failures):**
  - Tuyệt đối cấm `catch {}` rỗng hoặc dùng `try?` để bỏ qua lỗi mà không có log chẩn đoán.
  - Chỉ được dùng `try?` khi sự thất bại hoàn toàn là một kết quả hợp lệ được mong đợi trong luồng nghiệp vụ (ví dụ: kiểm tra xem file có tồn tại không) và **bắt buộc phải có comment giải thích**.
* **R10.3 Chuẩn hóa kiểu lỗi:**
  - Định nghĩa enum lỗi tập trung `AppError` hoặc enum lỗi riêng cho từng module (có conform `LocalizedError` và map được về `AppError`).
  - Phân tách rõ: Thông điệp lỗi hiển thị cho người dùng (thân thiện, có hướng giải quyết) và Thông điệp kỹ thuật ghi vào Log (chi tiết mã lỗi, nguyên nhân gốc rễ).
* **R10.4 Cấm lạm dụng `fatalError` / `preconditionFailure`:**
  - Tuyệt đối không gọi `fatalError` cho các tình huống runtime có thể xảy ra (mạng chập chờn, file hỏng, giải mã JSON thất bại).
  - Chỉ dùng cho lỗi lập trình không thể xảy ra (logical impossibility) kèm theo lời giải thích chi tiết.

---

## 11. Swift Concurrency & An toàn Luồng (Thread Safety)

* **R11.1 Swift Concurrency Hiện đại:** Sử dụng `async`/`await`, `actor`, và `TaskGroup`. Không dùng `DispatchGroup` hay callback completion lồng nhau cho code mới.
* **R11.2 UI duy nhất trên MainActor:** Mọi thao tác cập nhật trạng thái UI, ViewModel property phải chạy trên `@MainActor`. Không dùng `DispatchQueue.main.async` rải rác nếu `@MainActor` giải quyết được.
* **R11.3 Xử lý nặng ngoài MainActor:** Các tác vụ nặng (giải mã media, render khung hình, xử lý ảnh/video, export file, parsing dữ liệu lớn) **tuyệt đối cấm chạy trên main thread/MainActor**.
* **R11.4 Hủy tác vụ hợp tác (Cooperative Task Cancellation):**
  - Tác vụ bất đồng bộ phải kiểm tra trạng thái hủy: Gọi `Task.checkCancellation()` hoặc kiểm tra `Task.isCancelled` định kỳ trong các vòng lặp tính toán nặng.
  - Khi tác vụ cha bị hủy (người dùng chuyển màn hình, cuộn qua vùng nhìn), các sub-tasks tương ứng phải được dọn dẹp tài nguyên ngay lập tức.
* **R11.5 Strict Concurrency (Swift 6):**
  - Không tắt cảnh báo concurrency bằng cách thêm `@unchecked Sendable` hoặc `nonisolated(unsafe)` bừa bãi.
  - Sử dụng `@unchecked Sendable` chỉ khi cấu trúc dữ liệu bên trong thực sự tự bảo vệ luồng bằng cơ chế lock/mutex cấp thấp của hệ thống, và **bắt buộc phải có comment giải trình chi tiết**.
* **R11.6 Quản lý Tác vụ nền & Cache:** Tác vụ sinh dữ liệu phụ (thumbnail, audio waveform, preview frames) đặt ở `Infrastructure`. Bộ nhớ cache phải do `actor` độc lập quản lý. Không dồn toàn bộ tính toán vào trong actor vì sẽ gây tắc nghẽn tuần tự; actor chỉ quản lý trạng thái, việc tính toán chạy phân tán qua `Task`.

---

## 12. Logging & Quan sát (Apple Unified Logging)

* **R12.1 Dùng `os.Logger` thống nhất:** Sử dụng hệ thống logging hiện đại của Apple:
  ```swift
  import OSLog
  extension Logger {
      private static let subsystem = Bundle.main.bundleIdentifier ?? "com.app"
      static let timeline = Logger(subsystem: subsystem, category: "Timeline")
      static let network = Logger(subsystem: subsystem, category: "Network")
  }
  ```
* **R12.2 Cấm tuyệt đối `print()`:**
  - Cấm sử dụng hàm `print()` hoặc `NSLog` trong mã nguồn sản phẩm.
  - SwiftLint kiểm soát cưỡng chế lỗi `no_print` ở mức **Error**.
* **R12.3 Cấu trúc & Mức độ Log:** Sử dụng đúng mức độ log (`debug`, `info`, `notice`, `error`, `fault`). Log lỗi phải cung cấp ngữ cảnh đầy đủ để tái hiện, nhưng tuyệt đối không log dữ liệu nhạy cảm.

---

## 13. Quy ước Đặt tên & Chất lượng Mã nguồn Swift

Tuân thủ nghiêm ngặt **Swift API Design Guidelines**:

| Đối tượng | Quy chuẩn đặt tên | Ví dụ chuẩn |
|---|---|---|
| **Class, Struct, Enum, Actor** | `PascalCase`, danh từ | `ClipModel`, `TimelineRenderer`, `UserSession` |
| **Protocol mô tả bản chất** | `PascalCase`, danh từ | `ClipCore`, `ProjectRepository` |
| **Protocol mô tả khả năng** | `PascalCase`, tính từ hoặc hậu tố `-able`/`-ible` | `Transformable`, `Serializable`, `Sendable` |
| **Hàm, Phương thức** | `lowerCamelCase`, bắt đầu bằng động từ | `renderFrame()`, `fetchProjects()`, `insertClip()` |
| **Biến, Thuộc tính** | `lowerCamelCase`, danh từ rõ nghĩa | `duration`, `timeRange`, `clipCount` |
| **Thuộc tính Boolean** | `lowerCamelCase`, tiền tố khẳng định | `isLoading`, `hasAudio`, `canUndo`, `shouldAutoPlay` |
| **Enum Cases** | `lowerCamelCase` | `case pending`, `case inProgress`, `case failed` |
| **Hằng số, Static Properties** | `lowerCamelCase` | `static let defaultTimeout: TimeInterval = 30.0` |

* **R13.1 Cấm tên viết tắt vô nghĩa:** Tuyệt đối cấm đặt tên kiểu: `temp`, `data2`, `arr`, `val`, `x1`. Ngoại lệ duy nhất: biến đếm vòng lặp siêu ngắn (`i`, `j`) hoặc tọa độ hình học toán học rõ ràng (`x`, `y`, `dx`, `dy`).
* **R13.2 Rõ ràng hơn ngắn gọn:** Đặt tên phải thể hiện được **nó là cái gì và làm gì**, không cố tình viết tắt để tiết kiệm ký tự.
* **R13.3 Viết Comment có giá trị:** Comment giải thích **TẠI SAO (Why)** làm như vậy, không mô tả lại những gì mã nguồn đã thể hiện rõ ràng (**What**). Cấm để lại code rác bị comment-out trong commit cuối cùng.
* **R13.4 Không tối ưu hóa sớm (No Premature Optimization):** Viết code tường minh, đúng kiến trúc trước. Chỉ tối ưu khi có số liệu đo đạc cụ thể từ công cụ profiling (Instruments: Time Profiler, Allocations, Leaks).

---

## 14. Kiểm thử Phần mềm (Testing Discipline)

* **R14.1 Unit Test cho Tầng Nghiệp vụ:** Toàn bộ logic trong `Domain` (Commands, Models, Value Objects), `ViewModels` và `Services` bắt buộc phải có Unit Test bao phủ.
* **R14.2 Sửa Bug bắt buộc kèm Test tái hiện (Regression Test):**
  - Khi nhận nhiệm vụ sửa một lỗi (bug): **bắt buộc viết một test case tái hiện đúng lỗi đó trước** (test chạy fail).
  - Sau khi sửa code, test case đó phải chạy pass. Cấm sửa mã nguồn rồi bỏ qua khâu viết test bảo vệ.
* **R14.3 Test độc lập & tất định:**
  - Test không phụ thuộc vào thứ tự chạy, không phụ thuộc vào thời gian thực tế của hệ thống.
  - Cấm gọi mạng thật hoặc ghi đè file thật trong unit test: bắt buộc dùng Mock/Stub qua Protocol.
* **R14.4 Cấm sửa test cho hợp với code sai:** Khi test bị fail, phải phân tích nguyên nhân gốc rễ. Cấm sửa assertion của test cho qua chỉ để nộp bài khi chưa chứng minh được test cũ bị sai yêu cầu nghiệp vụ.
* **R14.5 Contract Tests cho Cấp L:** Mỗi implementation của Infrastructure phải chạy qua bộ Contract Test của protocol Domain tương ứng để đảm bảo tính hoán đổi không gây lỗi.
* **R14.6 Kiểm thử Hồi quy Toàn diện (Zero Regression Verification):** Chạy toàn bộ bộ test liên quan trước và sau mọi thay đổi (thêm tính năng mới, cập nhật, hoặc sửa lỗi) để đảm bảo không có bất kỳ tính năng hiện có nào bị gãy đổ hoặc thay đổi hành vi ngầm.

---

## 15. Tích hợp AppKit / UIKit & Tối ưu Giao diện Đặc thù

* **R15.1 Đóng gói qua Representable:**
  - Khi SwiftUI không đáp ứng được yêu cầu về hiệu năng cao hoặc API cấp thấp (Timeline cuộn hàng nghìn clips, Canvas vẽ Metal trực tiếp): sử dụng AppKit (`NSView`/`NSViewController`) hoặc UIKit (`UIView`).
  - Toàn bộ code AppKit/UIKit bắt buộc phải được đóng gói sạch sẽ qua `NSViewRepresentable` / `UIViewRepresentable` bên trong thư mục `Bridge/` hoặc `Canvas/`.
* **R15.2 Trách nhiệm View thuần túy:** `NSViewController` hoặc `NSView` đóng vai trò là tầng View — chỉ tiếp nhận tương tác người dùng, vẽ giao diện và chuyển sự kiện về ViewModel. Tuyệt đối không chứa logic tính toán nghiệp vụ.
* **R15.3 Ngưỡng nới lỏng có kiểm soát:** Các file trong thư mục `Bridge/` và `Canvas/` được áp dụng cấu hình SwiftLint riêng (File ≤ 800 dòng, hàm ≤ 150 dòng) nhưng bắt buộc phải module hóa theo trách nhiệm (Hit-testing, Gesture, Drawing, Zoom/Scroll).

---

## 16. Quản lý Thư viện Bên thứ ba (SPM Discipline)

* **R16.1 Mặc định không dùng thư viện ngoài:** Ưu tiên tối đa các giải pháp có sẵn trong Apple SDK (`Foundation`, `SwiftUI`, `Network`, `CryptoKit`, `OSLog`).
* **R16.2 Quy trình phê duyệt nghiêm ngặt:** Nếu muốn đề xuất thêm một thư viện bên thứ ba, Agent phải cung cấp:
  1. Tên thư viện và giấy phép mã nguồn mở (MIT, Apache 2.0...).
  2. Lý do chính đáng tại sao Apple SDK không đáp ứng được hoặc tốn quá nhiều chi phí tự xây.
  3. Mức độ bảo trì của cộng đồng (stars, số release gần nhất).
  4. Phương án thay thế nếu không dùng thư viện.
  5. **Chờ người dùng phê duyệt tường minh trước khi thêm vào `Package.swift` hoặc Xcode project.**
* **R16.3 Ghim phiên bản chính xác:** Toàn bộ dependencies phải được ghim phiên bản cụ thể (exact version) và commit file `Package.resolved` vào Git. Cấm tự ý nâng cấp thư viện đang hoạt động ổn định.

---

# PHẦN III: CƯỠNG CHẾ BẰNG CÔNG CỤ & TỰ ĐỘNG HÓA

## 17. Cấu hình SwiftLint Chuẩn mực

Đặt file `.swiftlint.yml` tại thư mục gốc của dự án:

```yaml
# .swiftlint.yml — Cấu hình chuẩn tương thích SwiftLint 0.65.1+
opt_in_rules:
  - force_unwrapping          # Bắt buộc cấm ! — nâng lên error ở dưới
  - implicitly_unwrapped_optional
  - unhandled_throwing_task   # Bắt lỗi bị nuốt trong Task { try ... }
  - fatal_error_message       # Bắt fatalError không có thông điệp
  - empty_count               # Bắt dùng .count == 0 thay vì .isEmpty
  - first_where               # Bắt dùng .filter().first thay vì .first(where:)
  - redundant_nil_coalescing

disabled_rules: []

# Giới hạn kích thước nghiêm ngặt (R3.1)
file_length:
  warning: 300
  error: 300                  # Đặt error = warning để DoD không có lỗi = không có warning

function_body_length:
  warning: 50
  error: 50

type_body_length:
  warning: 250
  error: 400

cyclomatic_complexity:
  warning: 10
  error: 20

force_unwrapping:
  severity: error             # Nâng từ warning mặc định lên error (R10.1)

identifier_name:
  min_length: 1               # Cho phép biến 1 ký tự trong toán học/hình học: x, y, i, j
  excluded:
    - id
    - dx
    - dy
    - db

custom_rules:
  no_print:
    name: "Không dùng print"
    regex: '\bprint\('
    message: "Tuyệt đối không dùng print trong release code. Sử dụng Logger thống nhất (R12.2)."
    severity: error

  no_swiftui_in_domain:
    name: "Domain không import UI"
    regex: 'import\s+(SwiftUI|AppKit|UIKit)'
    included: "(^|/)Domain/.*\\.swift"
    message: "Tầng Domain phải là Swift thuần khiết, không phụ thuộc framework UI (R2.3)."
    severity: error
    excluded_match_kinds:
      - comment
      - string

  no_hardcoded_color:
    name: "Không hardcode màu sắc"
    regex: 'Color\(\s*(red:|white:|hue:)'
    excluded: "(^|/)DesignSystem/.*\\.swift"
    message: "Màu sắc phải lấy từ Token trong DesignSystem (R8.1)."
    severity: error

  no_feature_cross_import:
    name: "Cấm Feature import chéo"
    regex: 'import\s+Feature\w+'
    included: "(^|/)Features/.*\\.swift"
    message: "Feature không được import trực tiếp Feature khác (R2.2). Phải thông qua Domain."
    severity: error
    excluded_match_kinds:
      - comment
      - string
```

### Cấu hình lồng cho thư mục đặc thù `Bridge/` và `Canvas/`:
Tạo file `.swiftlint.yml` bên trong thư mục `Bridge/` hoặc `Canvas/`:
```yaml
file_length:
  warning: 500
  error: 800
function_body_length:
  warning: 80
  error: 150
```

---

## 18. Script Kiểm tra Ranh giới Kiến trúc (`check_imports.sh`)

SwiftLint không thể kiểm tra toàn diện danh sách allowlist theo tệp ngoài. Script shell dưới đây là chốt chặn bắt buộc trong CI và pre-commit hook:

```bash
#!/usr/bin/env bash
# check_imports.sh — Chạy kiểm tra ranh giới kiến trúc và hướng import
set -euo pipefail

fail=0

# 1. Kiểm tra Domain: UI framework cấm tuyệt đối; Non-UI framework chỉ cho phép nếu có trong allowlist
ALLOW_FILE="${DOMAIN_ALLOWLIST:-Config/domain-allowed-imports.txt}"
allowed=""
if [ -f "$ALLOW_FILE" ]; then
  allowed=$(sed 's/#.*//' "$ALLOW_FILE" | tr -s '[:space:]' ' ')
fi

ui_frameworks="SwiftUI AppKit UIKit"
nonui_frameworks="AVFoundation Metal MetalKit CoreImage CoreGraphics CoreVideo Combine"

while IFS= read -r file; do
  # Kiểm tra UI Frameworks trong Domain
  for fw in $ui_frameworks; do
    if grep -E "^import[[:space:]]+$fw([[:space:]]|\$)" "$file" > /dev/null 2>&1; then
      echo "❌ [VI PHẠM] Domain import framework UI ($fw): $file"
      fail=1
    fi
  done

  # Kiểm tra Non-UI Frameworks trong Domain
  for fw in $nonui_frameworks; do
    case " $allowed " in *" $fw "*) continue ;; esac
    if grep -E "^import[[:space:]]+$fw([[:space:]]|\$)" "$file" > /dev/null 2>&1; then
      echo "❌ [VI PHẠM] Domain import $fw chưa được cấp phép trong $ALLOW_FILE: $file"
      fail=1
    fi
  done
done < <(find . -path "*/Domain/*.swift" -not -path "*/.build/*" -not -path "*/DerivedData/*")

# 2. Kiểm tra cấm Feature import chéo Feature khác
while IFS= read -r file; do
  feature_name=$(echo "$file" | sed -E 's|.*/Features/([^/]+)/.*|\1|')
  if grep -E "^import[[:space:]]+Feature" "$file" | grep -v "import[[:space:]]+Feature${feature_name}" > /dev/null 2>&1; then
    echo "❌ [VI PHẠM] Feature import chéo: $file"
    fail=1
  fi
done < <(find . -path "*/Features/*/*.swift" -not -path "*/.build/*" -not -path "*/DerivedData/*")

if [ $fail -eq 0 ]; then
  echo "✅ Toàn bộ kiểm tra import ranh giới đều ĐẠT chuẩn!"
fi

exit $fail
```

Tạo file `Config/domain-allowed-imports.txt` ở thư mục gốc repo để quản lý các framework ngoại lệ (mỗi mục phải có ADR đính kèm).

---

# PHẦN IV: CHECKLIST, QUY TRÌNH & MẪU TÀI LIỆU

## 19. Cấu trúc thư mục mẫu

### Cấu trúc Cấp S (App vừa & nhỏ)
```text
Root/
 ├── App/
 │    ├── AppMain.swift                # Điểm khởi đầu ứng dụng, Composition Root
 │    └── Config/
 │         └── domain-allowed-imports.txt
 ├── Features/                         # Các phân hệ nghiệp vụ độc lập
 │    ├── Timeline/
 │    │    ├── View/
 │    │    ├── ViewModel/
 │    │    └── Service/                # Service nội bộ của Feature (nếu chỉ mình nó dùng)
 │    └── Inspector/
 │         ├── View/
 │         └── ViewModel/
 ├── Domain/                           # Nghiệp vụ lõi (Thuần khiết, không UI)
 │    ├── Models/
 │    ├── Protocols/
 │    ├── Commands/
 │    └── Events/
 ├── DesignSystem/                     # Hệ thống giao diện dùng chung
 │    ├── Tokens/                      # Colors, Typography, Spacing
 │    └── Controls/                    # Buttons, Sliders, Toggles
 ├── Infrastructure/                   # Hiện thực I/O, File, Network, Storage
 └── Tests/
      ├── DomainTests/
      └── FeatureTests/
```

### Cấu trúc Cấp L (App lớn / Swift Package đa Target)
```text
Root/
 ├── Packages/
 │    └── AppCore/                     # Swift Package cục bộ nội bộ
 │         ├── Package.swift           # Khai báo các target & dependencies độc lập
 │         ├── Sources/
 │         │    ├── Domain/            # Target Domain lõi
 │         │    ├── DesignSystem/      # Target Design System
 │         │    ├── Infrastructure/    # Target Infrastructure
 │         │    ├── FeatureTimeline/   # Target Feature Timeline
 │         │    ├── FeatureInspector/  # Target Feature Inspector
 │         │    └── FeatureExport/     # Target Feature Export
 │         └── Tests/
 │              ├── DomainTests/
 │              ├── ContractTests/     # Kiểm tra hợp đồng giữa Domain & Infra
 │              └── FeatureTimelineTests/
 ├── App/                              # Target Xcode chính (import AppCore, lắp ráp)
 │    ├── AppMain.swift                # Khởi tạo DI, gọi registerAllTypes()
 │    └── Resources/
 └── docs/
      └── adr/                         # Lưu trữ các quyết định kiến trúc ngoại lệ
```

---

## 20. Checklist chống lỗi "Vibe-code" (Dành cho Agent tự vấn trước khi nộp)

Trước khi gửi báo cáo hoàn thành nhiệm vụ, Agent phải tự rà soát và trả lời trung thực 10 câu hỏi sau:

1. Tôi có **tạo bản sao** của hàm, control, modifier, hay extension đã có sẵn trong codebase không?
2. Tôi có viết logic nghiệp vụ, tính toán nặng, hoặc closure dài vào trong `View` (hoặc `NSViewController`) không?
3. Tôi có viết lệnh `switch` trên danh sách kiểu đối tượng cụ thể ở Timeline, Inspector, hoặc Renderer không? (Vi phạm R5.2)
4. Có bất kỳ hằng số, chuỗi hiển thị, màu sắc, hay padding nào bị **hardcode** trực tiếp không?
5. Trong mã nguồn có sót bất kỳ dấu force unwrap (`!`), `try!`, `as!`, hoặc `try?` nuốt lỗi không có lý do không?
6. Tôi có vô tình chỉnh sửa các file nằm ngoài phạm vi được người dùng giao không?
7. Khi bổ sung tính năng/đối tượng mới, tôi có phải mở file code cũ ra để sửa đổi không? (Nếu có → sai kiến trúc Mở/Đóng)
8. Tôi đã **thực sự chạy** lệnh `swift build`, `swift test`, và `swiftlint` trên terminal chưa, hay chỉ đoán là sẽ chạy được?
9. Tôi có kiểm tra xem thay đổi này có gây hồi quy (regression) làm hỏng tính năng khác hoặc thay đổi hành vi ngầm của code cũ không?
10. Báo cáo của tôi có **dán nguyên văn terminal output** không, hay đang tự tường thuật văn xuôi?
11. Nếu đây là một task refactor: Tôi đã kiểm tra đối chiếu với baseline vi phạm cũ chưa, và có tạo thêm bất kỳ cảnh báo/lỗi mới nào không?

---

## 21. Definition of Done (Định nghĩa "Xong" Chuẩn mực)

Một công việc **chỉ được coi là hoàn tất** khi đạt được **toàn bộ** các tiêu chí sau:

- [ ] **Biên dịch sạch:** Build hoàn tất với 0 lỗi, **không phát sinh bất kỳ warning mới nào**.
- [ ] **SwiftLint vượt qua:** Không có lỗi SwiftLint nào. Toàn bộ warning mới đều phải sửa hoặc có ADR ngoại lệ.
- [ ] **Ranh giới toàn vẹn:** Script `check_imports.sh` chạy thành công (không có import UI trong Domain, không import chéo Feature).
- [ ] **Cờ phụ thuộc SPM sạch (Cấp L):** `swift build --explicit-target-dependency-import-check error` không báo lỗi.
- [ ] **An toàn kiểu & luồng:** Không phát sinh mới bất kỳ `!`, `try!`, `as!`, `print()`, hoặc hardcode.
- [ ] **Không gây hồi quy (Zero Regression):** Toàn bộ các chức năng hiện có vẫn hoạt động chính xác; toàn bộ test suite cũ và mới đều **đã chạy và pass 100%**. Sửa bug có kèm test tái hiện.
- [ ] **Đúng phạm vi:** Diff nhỏ gọn, không sửa file ngoài yêu cầu, không tự ý dọn dẹp định dạng dòng không liên quan.
- [ ] **Báo cáo trung thực:** Trình bày đầy đủ báo cáo theo mẫu (Mục 22) và **dán nguyên văn log output** của các lệnh kiểm tra.

---

## 22. Mẫu Kế hoạch, Báo cáo & Quyết định Kiến trúc (ADR)

### Mẫu Kế hoạch (Trước khi code — Áp dụng khi chạm ngưỡng quy định)
```markdown
### KẾ HOẠCH THỰC THI
- **Mục tiêu (1-2 câu):** [Mô tả ngắn gọn mục đích]
- **Giả định kỹ thuật:** [Các giả định đang dùng]
- **File dự kiến tạo mới / sửa đổi:**
  - `[Tạo mới] [Tầng] Path/To/NewFile.swift`
  - `[Sửa đổi] [Tầng] Path/To/ExistingFile.swift`
- **Protocol / Command / Descriptor mới (nếu có):** [Mô tả vắn tắt]
- **Rủi ro & Phần chưa chắc chắn:** [Rủi ro tiềm ẩn, API chưa chắc chắn]
- **Cách thức kiểm chứng:** [Lệnh build, tên test case sẽ chạy]
```

### Mẫu Báo cáo (Sau khi code)
```markdown
### BÁO CÁO KẾT QUẢ THỰC THI
- **Đã làm:** [Liệt kê danh sách file đã thao tác và tóm tắt thay đổi logic]
- **Đã kiểm chứng thực tế:**
  *(Dán nguyên văn output terminal — KHÔNG tự tường thuật)*
  ```text
  [PASTE OUTPUT LỆNH BUILD / TEST / SWIFTLINT VÀO ĐÂY]
  ```
- **Chưa làm / Chưa kiểm chứng:** [Nêu rõ phần chưa chạy được hoặc tính năng để lại]
- **Giả định đã áp dụng:** [Các giả định trong quá trình code]
- **Phát hiện nhưng chưa xử lý (Nợ kỹ thuật):** [Vi phạm cũ trong codebase phát hiện thêm]
```

### Mẫu Architecture Decision Record (ADR)
Lưu tại `docs/adr/NNN-ten-quyet-dinh.md`:
```markdown
# ADR [NNN]: [Tên Quyết Định Ngắn Gọn]

- **Trạng thái:** [Đã duyệt | Đang đề xuất]
- **Ngày:** [YYYY-MM-DD]
- **Người duyệt:** [Tên người dùng / Lead]
- **Điều khoản Hiến pháp bị vi phạm:** [Ví dụ: R2.3 — Cho phép import framework X vào Domain]

### 1. Bối cảnh
[Mô tả vấn đề kỹ thuật gặp phải và lý do tại sao không thể tuân thủ điều khoản tiêu chuẩn]

### 2. Quyết định Kỹ thuật
[Mô tả giải pháp ngoại lệ được áp dụng]

### 3. Đánh đổi & Rủi ro
[Nêu rõ các đánh đổi về mặt kiến trúc, phụ thuộc nền tảng, hoặc chi phí bảo trì sau này]
```

---

## 23. Checklist Kiểm tra Nhanh Trước khi Bàn giao (Pre-Delivery Checklist)

- [ ] Chỉ chạm đúng file và dòng mã nguồn cần thiết; git diff sạch sẽ, không có thay đổi vô can.
- [ ] Không làm thay đổi hay phá vỡ hợp đồng giao tiếp (API signatures, protocol requirements) đang có.
- [ ] Không gây tác dụng phụ (side-effects) làm hỏng hoặc sai lệch bất kỳ tính năng hiện có nào (Zero Regression).
- [ ] Không có file nào vượt quá 300 dòng và không có hàm nào vượt quá 50 dòng (hoặc có ADR ngoại lệ).
- [ ] Không có API keys, passwords, hoặc secret nào nằm trong mã nguồn hay commit git.
- [ ] Toàn bộ các tác vụ I/O, async đều có xử lý lỗi đầy đủ; tuyệt đối không nuốt lỗi.
- [ ] Không xóa bất kỳ assertion, validation, hay log chẩn đoán cũ nào của hệ thống.
- [ ] Không bổ sung bất kỳ Swift Package nào khi chưa có sự đồng ý của người dùng.
- [ ] Đã chạy thực tế `swift build`, `swift test`, `swiftlint`, `check_imports.sh` và dán log nguyên văn.
- [ ] Báo cáo nêu rõ ràng và trung thực phần việc đã hoàn tất và các điểm lưu ý tồn đọng.
