import SwiftUI
import Testing
import Domain
import DesignSystem
@testable import FeatureShell

private struct MockThumbnailService: AssetThumbnailServiceProtocol {
    func generateThumbnailData(for asset: MediaAsset) async throws -> Data? {
        nil
    }
}

@Suite("DSMarqueeSelectionTests")
@MainActor
struct DSMarqueeSelectionTests {

    @Test("DSMarqueeSelectionView initializes with valid rect")
    func testDSMarqueeSelectionViewInitialization() {
        let rect = CGRect(x: 15, y: 25, width: 150, height: 80)
        let marquee = DSMarqueeSelectionView(rect: rect)
        #expect(marquee.rect == rect)
    }

    @Test("TimelineMarqueeSelectionView wraps DSMarqueeSelectionView")
    func testTimelineMarqueeSelectionViewDelegation() {
        let rect = CGRect(x: 10, y: 20, width: 100, height: 50)
        let timelineMarquee = TimelineMarqueeSelectionView(rect: rect)
        #expect(timelineMarquee.rect == rect)
    }

    @Test("MediaLibrary dragSelection updates selection identically across rect bounds")
    func testMediaLibraryDragSelectionIntersects() {
        let vm = MediaLibraryViewModel(thumbnailService: MockThumbnailService())
        let id1 = UUID()
        let id2 = UUID()
        let frames: [UUID: CGRect] = [
            id1: CGRect(x: 10, y: 10, width: 80, height: 80),
            id2: CGRect(x: 110, y: 10, width: 80, height: 80)
        ]

        let marquee = CGRect(x: 0, y: 0, width: 50, height: 50)
        vm.updateDragSelection(rect: marquee, itemFrames: frames)
        #expect(vm.selectedAssetIDs == [id1])

        let spanningMarquee = CGRect(x: 0, y: 0, width: 200, height: 100)
        vm.updateDragSelection(rect: spanningMarquee, itemFrames: frames)
        #expect(vm.selectedAssetIDs == [id1, id2])
    }
}
