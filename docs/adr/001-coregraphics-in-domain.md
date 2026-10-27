# ADR-001: Cho phép CoreGraphics trong Domain

- **Trạng thái:** CHỜ DUYỆT
- **Điều khoản vi phạm:** R2.3
- **Bối cảnh:** `AutoPanEngine`, `ExportConfiguration`, `CanvasAspectRatio` dùng `CGSize`/`CGRect`/`CGPoint`.
- **Quyết định:** Chỉ cho phép các kiểu giá trị hình học (`CGFloat`, `CGSize`, `CGPoint`, `CGRect`, `CGAffineTransform`). Cấm `CGContext`, `CGImage` và mọi API vẽ.
- **Rủi ro / đánh đổi:** Domain phụ thuộc thêm một framework hệ thống (có sẵn trên mọi nền tảng Apple). Phương án thay thế là tự định nghĩa struct hình học, nhưng sẽ tốn công chuyển đổi ở mọi ranh giới.
- **Người duyệt:** _(chưa có)_
