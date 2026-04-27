import Foundation

/// Feature flags backed by UserDefaults. Default off — explicit opt-in via
/// Settings debug section (#if DEBUG only) or programmatic UserDefaults write.
///
/// Adding a flag: add a static computed property here + a #if DEBUG toggle
/// in SettingsView. Release build: flag exists but UI is hidden.
enum FeatureFlags {
    /// v1.4 Proactive session rotation — dual ws + crossfade to eliminate
    /// the 38.5s loop trade-off of v1.3 reactive path.
    /// Default: OFF (reactive 路径不变). Toggle via Settings debug section.
    /// Design: docs/proactive-rotation-design.md
    static var proactiveRotation: Bool {
        UserDefaults.standard.bool(forKey: "feature_proactive_rotation")
    }
}
