# ADR-002: Tạm giữ FeatureShell là một target duy nhất

- **Trạng thái:** CHỜ DUYỆT
- **Điều khoản vi phạm:** R2.2, R2.7 (Cấp L yêu cầu mỗi feature là một target riêng)
- **Bối cảnh:** `FeatureShell` chứa Timeline, Inspector, Text, Adjustment, Preview, Export, Actions, Presets, MCP... Các phần này đang tham chiếu chéo qua `TimelineViewModel`.
- **Quyết định:** Giữ một target trong đợt tuân thủ hiện tại. Tách dần ở các đợt sau, bắt đầu từ những feature ít phụ thuộc nhất (Export, Presets).
- **Rủi ro / đánh đổi:** Compiler không ngăn được việc feature này import feature khác; tạm thời phải kiểm soát qua review.
- **Người duyệt:** _(chưa có)_
