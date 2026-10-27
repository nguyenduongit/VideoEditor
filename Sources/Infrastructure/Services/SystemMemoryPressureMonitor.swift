import Foundation
import Domain

/// Listens for OS-level low-memory / memory-pressure events on macOS and broadcasts
/// `Notification.Name.appDidReceiveMemoryWarning` so bounded caches can purge themselves.
public final class SystemMemoryPressureMonitor: @unchecked Sendable {
    private var source: (any DispatchSourceMemoryPressure)?
    private let queue = DispatchQueue(label: "com.videoeditor.memorypressure", qos: .utility)

    public init() {
        startMonitoring()
    }

    public func startMonitoring() {
        guard source == nil else { return }
        let newSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: queue
        )
        newSource.setEventHandler {
            NotificationCenter.default.post(
                name: .appDidReceiveMemoryWarning,
                object: nil
            )
        }
        newSource.resume()
        self.source = newSource
    }

    public func stopMonitoring() {
        source?.cancel()
        source = nil
    }

    deinit {
        stopMonitoring()
    }
}
