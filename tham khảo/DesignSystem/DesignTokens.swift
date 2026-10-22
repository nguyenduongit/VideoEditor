import AppKit

// MARK: - Design System Tokens
// Centralized design tokens for the entire application.
// All views MUST reference these tokens instead of hardcoding colors, spacing, or fonts.

public enum DS {
    
    // MARK: - Color Palette (Dark Pro Theme)
    
    public enum Color {
        // Backgrounds — layered from deepest to most elevated
        public static let appBg         = NSColor(red: 0.067, green: 0.075, blue: 0.094, alpha: 1.0)  // #111318
        public static let panelBg       = NSColor(red: 0.094, green: 0.106, blue: 0.129, alpha: 1.0)  // #181B21
        public static let surfaceBg     = NSColor(red: 0.125, green: 0.141, blue: 0.173, alpha: 1.0)  // #20242C
        public static let elevatedBg    = NSColor(red: 0.153, green: 0.173, blue: 0.212, alpha: 1.0)  // #272C36
        public static let hoverBg       = NSColor(red: 0.176, green: 0.200, blue: 0.243, alpha: 1.0)  // #2D333E
        
        // Borders & Dividers
        public static let border        = NSColor(red: 0.169, green: 0.188, blue: 0.227, alpha: 1.0)  // #2B303A
        public static let borderSubtle  = NSColor(red: 0.145, green: 0.161, blue: 0.196, alpha: 1.0)  // #252932
        public static let divider       = NSColor(red: 0.200, green: 0.220, blue: 0.263, alpha: 0.6)
        
        // Text Hierarchy
        public static let textPrimary   = NSColor(red: 0.949, green: 0.957, blue: 0.969, alpha: 1.0)  // #F2F4F7
        public static let textSecondary = NSColor(red: 0.651, green: 0.678, blue: 0.730, alpha: 1.0)  // #A6ADBA
        public static let textMuted     = NSColor(red: 0.435, green: 0.467, blue: 0.522, alpha: 1.0)  // #6F7785
        public static let textDisabled  = NSColor(red: 0.350, green: 0.375, blue: 0.420, alpha: 1.0)
        
        // Accent — Cyan-Blue
        public static let accent        = NSColor(red: 0.322, green: 0.694, blue: 0.886, alpha: 1.0)  // #52B1E2
        public static let accentHover   = NSColor(red: 0.400, green: 0.750, blue: 0.920, alpha: 1.0)
        public static let accentPressed = NSColor(red: 0.220, green: 0.565, blue: 0.760, alpha: 1.0)
        public static let accentMuted   = NSColor(red: 0.322, green: 0.694, blue: 0.886, alpha: 0.15)
        
        // Semantic Colors
        public static let success       = NSColor(red: 0.180, green: 0.780, blue: 0.420, alpha: 1.0)  // #2EC76B
        public static let successMuted  = NSColor(red: 0.180, green: 0.780, blue: 0.420, alpha: 0.15)
        public static let warning       = NSColor(red: 0.950, green: 0.680, blue: 0.150, alpha: 1.0)  // #F2AD26
        public static let warningMuted  = NSColor(red: 0.950, green: 0.680, blue: 0.150, alpha: 0.15)
        public static let error         = NSColor(red: 0.900, green: 0.250, blue: 0.300, alpha: 1.0)  // #E6404D
        public static let errorMuted    = NSColor(red: 0.900, green: 0.250, blue: 0.300, alpha: 0.15)
        
        // Waveform-specific
        public static let waveform          = NSColor(red: 0.420, green: 0.720, blue: 0.940, alpha: 0.90) // Xanh da trời nhạt
        public static let waveformPrimary   = NSColor(red: 0.480, green: 0.780, blue: 0.980, alpha: 1.0)
        public static let waveformSecondary = NSColor(red: 0.480, green: 0.780, blue: 0.980, alpha: 0.85)
        public static let waveformBg        = NSColor(red: 0.067, green: 0.082, blue: 0.110, alpha: 1.0)
        public static let beatLine          = NSColor(red: 0.200, green: 0.820, blue: 0.450, alpha: 0.85) // Xanh lá nhịp chính
        public static let beatBarLine       = NSColor(red: 0.130, green: 0.820, blue: 0.380, alpha: 0.95) // Xanh lá nổi bật
        public static let beatSubLine       = NSColor(red: 0.950, green: 0.720, blue: 0.180, alpha: 0.70) // Vàng phách phụ
        public static let gridLine          = NSColor(red: 0.160, green: 0.200, blue: 0.280, alpha: 0.60)
        public static let centerLine        = NSColor(red: 0.300, green: 0.360, blue: 0.460, alpha: 0.60)
        
        // Playhead & Markers
        public static let playhead      = NSColor(red: 0.950, green: 0.300, blue: 0.250, alpha: 1.0)  // Đỏ cam
        public static let markerStart   = NSColor(red: 0.200, green: 0.820, blue: 0.450, alpha: 1.0)  // Xanh lá
        public static let markerEnd     = NSColor(red: 0.950, green: 0.300, blue: 0.380, alpha: 1.0)  // Đỏ hồng
        public static let cutLine       = NSColor(red: 0.980, green: 0.550, blue: 0.120, alpha: 1.0)  // Cam đậm
        
        // Pipeline step colors
        public static let pipelineActive    = accent
        public static let pipelineCompleted = success
        public static let pipelineIdle      = textMuted
        
        // BPM & Volume accent colors (functional, not decorative)
        public static let bpmAccent     = NSColor(red: 0.950, green: 0.600, blue: 0.150, alpha: 1.0)  // Cam ấm
        public static let voiceAccent   = NSColor(red: 0.200, green: 0.750, blue: 0.420, alpha: 1.0)  // Xanh lá
    }
    
    // MARK: - Spacing (4px base grid)
    
    public enum Spacing {
        public static let xxs: CGFloat  = 2.0
        public static let xs: CGFloat   = 4.0
        public static let sm: CGFloat   = 8.0
        public static let md: CGFloat   = 12.0
        public static let lg: CGFloat   = 16.0
        public static let xl: CGFloat   = 24.0
        public static let xxl: CGFloat  = 32.0
        public static let xxxl: CGFloat = 48.0
    }
    
    // MARK: - Corner Radius
    
    public enum Radius {
        public static let xs: CGFloat   = 3.0
        public static let sm: CGFloat   = 4.0
        public static let md: CGFloat   = 6.0
        public static let lg: CGFloat   = 8.0
        public static let xl: CGFloat   = 10.0
        public static let panel: CGFloat = 8.0
    }
    
    // MARK: - Typography
    
    public enum Font {
        // System font hierarchy
        public static func header(_ size: CGFloat = 16, weight: NSFont.Weight = .bold) -> NSFont {
            return NSFont.systemFont(ofSize: size, weight: weight)
        }
        public static func title(_ size: CGFloat = 13) -> NSFont {
            return NSFont.systemFont(ofSize: size, weight: .semibold)
        }
        public static func label(_ size: CGFloat = 11.5) -> NSFont {
            return NSFont.systemFont(ofSize: size, weight: .medium)
        }
        public static func body(_ size: CGFloat = 12) -> NSFont {
            return NSFont.systemFont(ofSize: size, weight: .regular)
        }
        public static func button(_ size: CGFloat = 12, weight: NSFont.Weight = .semibold) -> NSFont {
            return NSFont.systemFont(ofSize: size, weight: weight)
        }
        public static func caption(_ size: CGFloat = 10.5, weight: NSFont.Weight = .regular) -> NSFont {
            return NSFont.systemFont(ofSize: size, weight: weight)
        }
        public static func mono(_ size: CGFloat = 11, weight: NSFont.Weight = .medium) -> NSFont {
            return NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        }
        public static func monoBold(_ size: CGFloat = 12) -> NSFont {
            return NSFont.monospacedDigitSystemFont(ofSize: size, weight: .bold)
        }
        public static func bold(_ size: CGFloat = 12) -> NSFont {
            return NSFont.systemFont(ofSize: size, weight: .bold)
        }
        public static func heavy(_ size: CGFloat = 11) -> NSFont {
            return NSFont.systemFont(ofSize: size, weight: .heavy)
        }
        public static func sectionTitle(_ size: CGFloat = 10) -> NSFont {
            return NSFont.systemFont(ofSize: size, weight: .heavy)
        }
        public static func monoConsole(_ size: CGFloat = 11.5) -> NSFont {
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
    }
    
    // MARK: - Sizes
    
    public enum Size {
        public static let toolbarHeight: CGFloat    = 38.0
        public static let transportHeight: CGFloat  = 36.0
        public static let statusBarHeight: CGFloat  = 22.0
        public static let rulerHeight: CGFloat      = 20.0
        public static let titleBarHeight: CGFloat   = 24.0
        public static let controlBarHeight: CGFloat = 108.0
        public static let detailHeaderHeight: CGFloat = 32.0
        
        public static let buttonHeight: CGFloat     = 28.0
        public static let smallButtonHeight: CGFloat = 24.0
        public static let iconButtonSize: CGFloat   = 28.0
        public static let iconSize: CGFloat         = 14.0
        public static let smallIconSize: CGFloat    = 12.0
        
        public static let sliderHeight: CGFloat     = 20.0
        public static let dividerWidth: CGFloat     = 1.0
        public static let borderWidth: CGFloat      = 1.0
        public static let thinBorder: CGFloat       = 0.5
        
        public static let minWindowWidth: CGFloat   = 950.0
        public static let minWindowHeight: CGFloat  = 650.0
    }
    
    // MARK: - Animation
    
    public enum Animation {
        public static let fast: CFTimeInterval      = 0.12
        public static let normal: CFTimeInterval    = 0.18
        public static let slow: CFTimeInterval      = 0.25
    }
    
    // MARK: - SF Symbol Helpers
    
    public static func symbol(_ name: String, size: CGFloat = 12, weight: NSFont.Weight = .medium) -> NSImage? {
        guard let img = NSImage(systemSymbolName: name, accessibilityDescription: name) else { return nil }
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
        return img.withSymbolConfiguration(config)
    }
    
    public static func symbolBold(_ name: String, size: CGFloat = 12) -> NSImage? {
        return symbol(name, size: size, weight: .bold)
    }
}

// MARK: - NSColor convenience initializer

extension NSColor {
    convenience init(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat = 1.0) {
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - NSView styling extensions

extension NSView {
    /// Apply standard panel styling (dark surface with subtle border)
    func applyPanelStyle(bg: NSColor = DS.Color.panelBg, radius: CGFloat = DS.Radius.panel) {
        wantsLayer = true
        layer?.backgroundColor = bg.cgColor
        layer?.cornerRadius = radius
        layer?.borderWidth = DS.Size.borderWidth
        layer?.borderColor = DS.Color.border.cgColor
    }
    
    /// Apply surface styling (slightly elevated from panel)
    func applySurfaceStyle(radius: CGFloat = DS.Radius.md) {
        wantsLayer = true
        layer?.backgroundColor = DS.Color.surfaceBg.cgColor
        layer?.cornerRadius = radius
        layer?.borderWidth = DS.Size.thinBorder
        layer?.borderColor = DS.Color.borderSubtle.cgColor
    }
    
    /// Apply toolbar/control bar styling
    func applyToolbarStyle() {
        wantsLayer = true
        layer?.backgroundColor = DS.Color.panelBg.cgColor
        layer?.cornerRadius = 0
        layer?.borderWidth = DS.Size.thinBorder
        layer?.borderColor = DS.Color.divider.cgColor
    }
}
