import AppKit
import NoteCraftKit
import Observation

extension Notification.Name {
    static let editorSettingsDidChange = Notification.Name("NoteCraftEditorSettingsDidChange")
}

@MainActor
@Observable
final class SettingsStore {
    static let shared = SettingsStore(defaults: .standard)
    static let settingsKey = "EditorSettings"
    static let quitAlwaysKeepsWindowsKey = "NSQuitAlwaysKeepsWindows"

    @ObservationIgnored private let defaults: UserDefaults

    var settings: EditorSettings {
        didSet {
            guard settings != oldValue else { return }
            settings.clamp()
            persist()
            NotificationCenter.default.post(name: .editorSettingsDidChange, object: self)
        }
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.settingsKey),
           let decoded = try? JSONDecoder().decode(EditorSettings.self, from: data) {
            settings = decoded
        } else {
            settings = EditorSettings()
        }
        applySessionRestoration()
    }

    /// Changes a single setting through a key path.
    func update<Value>(_ keyPath: WritableKeyPath<EditorSettings, Value>, to value: Value) {
        settings[keyPath: keyPath] = value
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Self.settingsKey)
        }
        applySessionRestoration()
    }

    private func applySessionRestoration() {
        defaults.set(settings.restoresSession, forKey: Self.quitAlwaysKeepsWindowsKey)
    }
}
