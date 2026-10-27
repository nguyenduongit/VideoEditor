# ADR-003: Hoãn Localization

- **Trạng thái:** CHỜ DUYỆT
- **Điều khoản vi phạm:** R9.2
- **Bối cảnh:** Hiện có khoảng 58+ chuỗi viết thẳng trong `Text("…")`, chưa có String Catalog.
- **Quyết định:** Hoãn sang một đợt riêng. Từ nay code mới phải dùng `String(localized:)`.
- **Rủi ro / đánh đổi:** Nợ kỹ thuật tăng theo số lượng UI mới viết thêm.
- **Người duyệt:** _(chưa có)_
