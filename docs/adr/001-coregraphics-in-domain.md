# ADR-001: Loại bỏ CoreGraphics khỏi Domain (Đưa Domain về 100% thuần khiết)

- **Trạng thái:** ĐÃ GIẢI QUYẾT (RESOLVED)
- **Ngày:** 2026-10-27
- **Người duyệt:** Nguyễn Quốc Dương
- **Điều khoản liên quan:** R2.3 (Đã tuân thủ 100%)
- **Bối cảnh ban đầu:** `AutoPanEngine`, `ExportConfiguration`, `CanvasAspectRatio` sử dụng `CGSize`/`CGRect`/`CGPoint` dẫn đến việc phải import `CoreGraphics` vào Domain.
- **Quyết định giải quyết:** 
  1. Loại bỏ toàn bộ `import CoreGraphics` khỏi tầng `Domain`.
  2. `AutoPanEngine` đã xóa import thừa không sử dụng.
  3. `CanvasAspectRatio` và `ExportConfiguration` chuyển sang sử dụng kiểu dữ liệu nguyên thủy thuần Swift (`Int`, `Double`).
  4. Tạo các extension bắc cầu (`CanvasAspectRatio+CoreGraphics.swift`, `ExportResolution+CoreGraphics.swift`) tại tầng `FeatureShell` để phục vụ hiển thị UI và AVFoundation mà không làm rò rỉ framework đồ họa vào lõi Domain.
- **Kết quả:** Domain đạt 100% độ thuần khiết theo R2.3. File `Config/domain-allowed-imports.txt` đã xóa `CoreGraphics`. `check_imports.sh` và test suite (436 tests) vượt qua 100%.

