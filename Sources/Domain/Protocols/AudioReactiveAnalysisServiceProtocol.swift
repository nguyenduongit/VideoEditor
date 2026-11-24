import Foundation

/// Domain boundary protocol for extracting and caching 30Hz multi-band `AudioReactiveProfile` spectra.
/// Concrete Accelerate FFT implementation lives in `Infrastructure`.
public protocol AudioReactiveAnalysisServiceProtocol: Sendable {
    /// Returns an already extracted profile immediately without blocking if cached.
    func cachedProfile(for url: URL) -> AudioReactiveProfile?

    /// Decodes audio at `url`, extracts multi-band FFT levels, caches, and returns the profile.
    func extractReactiveProfile(from url: URL) async -> AudioReactiveProfile?
}
