# ADR-002: Tạm giữ FeatureShell là một target duy nhất

- **Trạng thái:** ĐÃ DUYỆT (ACCEPTED)
- **Ngày:** 2026-10-27
- **Người duyệt:** Nguyễn Quốc Dương
- **Điều khoản vi phạm:** R2.2, R2.7 (Cấp L yêu cầu mỗi feature là một target riêng)
- **Bối cảnh:** `FeatureShell` chứa Timeline, Inspector, Text, Adjustment, Preview, Export, Actions, Presets, MCP... Các thành phần này hiện đang chia sẻ các ViewModel (`TimelineViewModel`, `ShellViewModel`) ở quyền truy cập `internal`.
- **Quyết định:** Duyệt chấp thuận giữ `FeatureShell` là một target duy nhất trong giai đoạn hiện tại nhằm bảo đảm tính ổn định tối đa của hệ thống và tránh hồi quy (Zero Regression). Tạm thời kiểm soát ranh giới giữa các feature thông qua quy ước cấu trúc thư mục và quy trình Code Review nghiêm ngặt. Khi hệ thống mở rộng, việc phân tách sẽ thực hiện theo lộ trình an toàn từ ít phụ thuộc nhất: Presets → Export → Actions → Media → Inspector → Timeline.
- **Rủi ro / đánh đổi:** Trình biên dịch chưa tự động ngăn chặn được việc truy cập chéo giữa các thư mục feature; yêu cầu kỷ luật cao khi viết code và review để không tạo thêm phụ thuộc chéo mới.

