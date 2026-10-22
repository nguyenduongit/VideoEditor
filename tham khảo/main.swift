import AppKit

// AppKit khởi động file `main.swift` trên main thread; khai báo ranh giới actor
// để compiler kiểm tra toàn bộ vòng đời UI theo MainActor.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}
