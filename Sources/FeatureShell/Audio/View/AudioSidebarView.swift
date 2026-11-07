import SwiftUI
import Domain
import DesignSystem

/// Giao diện Sidebar hiển thị danh mục công cụ âm thanh và tính năng Dance Beat Counter.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, View body <= 80 dòng) và R2.4 (DesignSystem).
public struct AudioSidebarView: View {
    public weak var timelineViewModel: TimelineViewModel?

    public init(timelineViewModel: TimelineViewModel? = nil) {
        self.timelineViewModel = timelineViewModel
    }

    private var canAdd: Bool {
        timelineViewModel?.canAddDanceBeatCounter ?? false
    }

    public var body: some View {
        LibraryScaffoldView(
            searchPlaceholder: "Tìm kiếm âm thanh, công cụ..."
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                sectionHeader
                danceBeatCounterCard
                Spacer()
            }
            .padding(DSSpacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var sectionHeader: some View {
        Text(String(localized: "CÔNG CỤ THUẬT TOÁN"))
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(DSColors.textSecondary)
    }

    private var danceBeatCounterCard: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack(spacing: DSSpacing.md) {
                ZStack {
                    Circle()
                        .fill(DSColors.accent.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: "figure.dance")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DSColors.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Dance Beat Counter")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DSColors.textPrimary)
                        Spacer()
                        statusBadge
                    }

                    Text("Đếm nhịp 8 tự động khớp bài nhạc chính cho video dạy nhảy.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(DSColors.textSecondary)
                        .lineLimit(2)
                }
            }

            Divider().background(DSColors.blockBorder)

            HStack {
                if !canAdd {
                    Text("Cần có track nhạc chính trên timeline")
                        .font(.system(size: 10))
                        .foregroundStyle(DSColors.textSecondary.opacity(0.7))
                }
                Spacer()
                addButton
            }
        }
        .padding(DSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(DSColors.blockBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DSColors.blockBorder, lineWidth: 1)
                )
        )
    }

    private var statusBadge: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(canAdd ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Text(canAdd ? "Sẵn sàng" : "Chờ nhạc")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(canAdd ? Color.green : DSColors.textSecondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill((canAdd ? Color.green : Color.orange).opacity(0.12))
        )
    }

    private var addButton: some View {
        Button {
            timelineViewModel?.addDanceBeatCounter()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text("Thêm vào timeline")
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(canAdd ? DSColors.accent : DSColors.blockBorder)
            )
            .foregroundStyle(canAdd ? Color.white : DSColors.textSecondary.opacity(0.7))
        }
        .buttonStyle(.plain)
        .disabled(!canAdd)
    }
}
