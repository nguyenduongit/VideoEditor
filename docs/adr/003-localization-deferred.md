# ADR-003: Triển khai Localization & Giải quyết ngoại lệ hoãn

- **Trạng thái:** ĐÃ GIẢI QUYẾT (RESOLVED)
- **Ngày:** 2026-10-27
- **Người duyệt:** Nguyễn Quốc Dương
- **Điều khoản liên quan:** R9.2 (Đã tuân thủ 100%)
- **Bối cảnh ban đầu:** Dự án tồn đọng 58+ chuỗi trôi nổi trong `Text("…")`, chưa qua cơ chế bản địa hóa.
- **Quyết định giải quyết:** Triển khai toàn diện cơ chế localization sử dụng API chuẩn `String(localized:)` của Foundation trên macOS 14+ / Swift 6 cho toàn bộ các nhãn hiển thị trong Views, Buttons, TextFields, Modals, và Inspector.
- **Kết quả:** Vi phạm R9.2 đã được triệt tiêu hoàn toàn, không còn ngoại lệ hoãn. Toàn bộ chuỗi UI mới phát sinh bắt buộc tiếp tục tuân thủ `String(localized:)`.
