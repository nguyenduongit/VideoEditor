import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    var mainWindowController: MainWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Thiết lập App Icon trực tiếp cho Dock Tile
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let iconImage = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = iconImage
        }
        
        // Thiết lập menu bar hệ thống
        MainMenuBuilder.setupMenu(appName: "Video Auto Editor")
        
        // Khởi tạo và hiển thị cửa sổ chính
        let controller = MainWindowController()
        self.mainWindowController = controller
        controller.showWindow(nil)
        
        // Tối đa hóa cửa sổ (Maximize)
        controller.maximizeWindow()
        
        // Kích hoạt ứng dụng để nhận focus
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            if let windowController = mainWindowController {
                windowController.showWindow(nil)
                windowController.maximizeWindow()
            } else {
                let controller = MainWindowController()
                self.mainWindowController = controller
                controller.showWindow(nil)
                controller.maximizeWindow()
            }
        }
        return true
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if mainWindowController?.window?.isVisible == false { return .terminateNow }
        return mainWindowController?.editor.confirmDiscard() == false ? .terminateCancel : .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
