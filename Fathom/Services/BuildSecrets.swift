import Foundation

/// Secrets baked into the bundle at release time by `release-ota.sh`
/// (passed to xcodebuild as build settings that the Info plist
/// references). Empty in local Xcode builds.
///
/// Pattern: declare `MY_KEY: $(MY_KEY)` under `info.properties` in
/// project.yml, pass `MY_KEY=value` in the release script's
/// EXTRA_BUILD_SETTINGS, then on launch call
/// `BuildSecrets.seed(keychain, account: "my_key", fromInfoKey: "MY_KEY")`
/// so the value lands in the Keychain once.
/// Adapted from the Ingot package's BuildSecrets helper.
enum BuildSecrets {
    static func value(forInfoKey key: String) -> String? {
        guard let raw = Bundle.main.infoDictionary?[key] as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // An unexpanded "$(MY_KEY)" means the setting was never supplied.
        if trimmed.isEmpty || trimmed.hasPrefix("$(") { return nil }
        return trimmed
    }

    /// Copies a baked-in secret into the Keychain if that account is still empty.
    @discardableResult
    static func seed(_ keychain: Keychain, account: String, fromInfoKey key: String) -> Bool {
        guard (keychain.read(account) ?? "").isEmpty, let v = value(forInfoKey: key) else { return false }
        keychain.write(account, v)
        return true
    }
}
