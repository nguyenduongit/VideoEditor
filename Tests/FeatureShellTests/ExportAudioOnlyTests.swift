import Foundation
import CoreMedia
import Testing
import Domain
@testable import FeatureShell

@Suite("ExportAudioOnlyTests")
@MainActor
struct ExportAudioOnlyTests {

    @Test func testExportMediaTypeAndAudioFormatIdentifiable() {
        let mediaTypes = ExportMediaType.allCases
        #expect(mediaTypes.count == 2)
        #expect(mediaTypes[0] == .video)
        #expect(mediaTypes[1] == .audio)
        #expect(ExportMediaType.video.id == "Video (MP4)")
        #expect(ExportMediaType.audio.id == "Âm thanh (Audio Only)")

        let audioFormats = ExportAudioFormat.allCases
        #expect(audioFormats.count == 2)
        #expect(audioFormats[0] == .m4a)
        #expect(audioFormats[1] == .wav)
        #expect(ExportAudioFormat.m4a.fileExtension == "m4a")
        #expect(ExportAudioFormat.wav.fileExtension == "wav")
        #expect(ExportAudioFormat.m4a.defaultBitrateKbps == 256)
        #expect(ExportAudioFormat.wav.defaultBitrateKbps == 1536)
    }

    @Test func testExportViewModelAudioEstimatedSize() {
        let vm = ExportViewModel()
        vm.mediaType = .audio
        vm.audioFormat = .m4a

        let duration60s = CMTime(seconds: 60, preferredTimescale: 600)
        let m4aText = vm.estimatedFileSize(duration: duration60s, aspectRatio: .ratio16x9)
        #expect(m4aText == "1.9 MB")

        vm.audioFormat = .wav
        let wavText = vm.estimatedFileSize(duration: duration60s, aspectRatio: .ratio16x9)
        #expect(wavText == "11.5 MB")
    }

    @Test func testExportViewModelOpenDialogMediaType() {
        let vm = ExportViewModel()
        #expect(vm.isPresented == false)
        #expect(vm.mediaType == .video)

        vm.openDialog(mediaType: .audio)
        #expect(vm.isPresented == true)
        #expect(vm.mediaType == .audio)

        vm.closeDialog()
        #expect(vm.isPresented == false)

        vm.openDialog(mediaType: .video)
        #expect(vm.isPresented == true)
        #expect(vm.mediaType == .video)
    }
}
