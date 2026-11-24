import Foundation

/// Gói các dịch vụ dùng chung của editor, được khởi tạo DUY NHẤT tại Composition Root (App)
/// và inject xuống Features. Thay thế các singleton `.shared` cũ (AGENTS.md R3.3, R2.5).
public struct EditorDependencies: Sendable {
    public let propertyRegistry: ClipPropertyRegistry
    public let textTemplates: TextTemplateLoader
    public let adjustmentTemplates: AdjustmentTemplateLoader
    public let effectLibrary: EffectLibrary
    public let transitionLibrary: TransitionLibrary
    public let stickerLibrary: StickerLibrary
    public let presetRepositories: PresetRepositoryProvider
    public let actionRepositories: ActionRepositoryProvider

    /// Mặc định tạo instance mới, độc lập — dùng cho test và preview.
    /// Môi trường chạy thật phải truyền một instance dùng chung từ App.
    public init(
        propertyRegistry: ClipPropertyRegistry = ClipPropertyRegistry(),
        textTemplates: TextTemplateLoader = TextTemplateLoader(),
        adjustmentTemplates: AdjustmentTemplateLoader = AdjustmentTemplateLoader(),
        effectLibrary: EffectLibrary = EffectLibrary(),
        transitionLibrary: TransitionLibrary = TransitionLibrary(),
        stickerLibrary: StickerLibrary = StickerLibrary(),
        presetRepositories: PresetRepositoryProvider = PresetRepositoryProvider(),
        actionRepositories: ActionRepositoryProvider = ActionRepositoryProvider()
    ) {
        self.propertyRegistry = propertyRegistry
        self.textTemplates = textTemplates
        self.adjustmentTemplates = adjustmentTemplates
        self.effectLibrary = effectLibrary
        self.transitionLibrary = transitionLibrary
        self.stickerLibrary = stickerLibrary
        self.presetRepositories = presetRepositories
        self.actionRepositories = actionRepositories
    }
}
