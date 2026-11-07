import Foundation

/// Gói các dịch vụ dùng chung của editor, được khởi tạo DUY NHẤT tại Composition Root (App)
/// và inject xuống Features. Thay thế các singleton `.shared` cũ (AGENTS.md R3.3, R2.5).
public struct EditorDependencies: Sendable {
    public let propertyRegistry: ClipPropertyRegistry
    public let textTemplates: TextTemplateLoader
    public let adjustmentTemplates: AdjustmentTemplateLoader
    public let effectTemplates: EffectTemplateLoader
    public let animationTemplates: AnimationTemplateLoader
    public let transitionTemplates: TransitionTemplateLoader
    public let stickerTemplates: StickerTemplateLoader
    public let presetRepositories: PresetRepositoryProvider
    public let actionRepositories: ActionRepositoryProvider

    /// Mặc định tạo instance mới, độc lập — dùng cho test và preview.
    /// Môi trường chạy thật phải truyền một instance dùng chung từ App.
    public init(
        propertyRegistry: ClipPropertyRegistry = ClipPropertyRegistry(),
        textTemplates: TextTemplateLoader = TextTemplateLoader(),
        adjustmentTemplates: AdjustmentTemplateLoader = AdjustmentTemplateLoader(),
        effectTemplates: EffectTemplateLoader = EffectTemplateLoader(),
        animationTemplates: AnimationTemplateLoader = AnimationTemplateLoader(),
        transitionTemplates: TransitionTemplateLoader = TransitionTemplateLoader(),
        stickerTemplates: StickerTemplateLoader = StickerTemplateLoader(),
        presetRepositories: PresetRepositoryProvider = PresetRepositoryProvider(),
        actionRepositories: ActionRepositoryProvider = ActionRepositoryProvider()
    ) {
        self.propertyRegistry = propertyRegistry
        self.textTemplates = textTemplates
        self.adjustmentTemplates = adjustmentTemplates
        self.effectTemplates = effectTemplates
        self.animationTemplates = animationTemplates
        self.transitionTemplates = transitionTemplates
        self.stickerTemplates = stickerTemplates
        self.presetRepositories = presetRepositories
        self.actionRepositories = actionRepositories
    }
}
