import Foundation

/// Identifiers shared by the app and the widget extension.
enum AppGroup {
    static let id = "group.com.vlasov.bottleofwater"

    nonisolated(unsafe) static let defaults: UserDefaults =
        UserDefaults(suiteName: id) ?? .standard
}

/// Static, release-relevant facts about the app.
enum AppInfo {
    /// One developer mailbox for all apps; the subject tells which app a message is about.
    static let supportEmail = "yar.thedeveloper@proton.me"
    static let supportSubject = "[Bottle of Water] Feedback"
    /// Numeric App Store ID, known after the app is created in App Store Connect.
    /// The "Rate" row is hidden while nil.
    static let appStoreID: String? = nil

    static let privacyPolicyURL = URL(string: "https://viktor100500.github.io/BottleOfWater/privacy/")!
    static let supportURL = URL(string: "https://viktor100500.github.io/BottleOfWater/")!

    /// Hardware identifier such as "iPhone17,1" (the simulator reports its host model).
    static var deviceModel: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulated }
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}

/// Cross-process "data changed" ping (widget / intents → running app).
enum ChangeNotifier {
    private static let name = "com.vlasov.bottleofwater.changed"
    nonisolated(unsafe) private static var handler: (@Sendable () -> Void)?

    static func post() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name as CFString), nil, nil, true)
    }

    /// Registers a single process-wide handler. Called once by the app at launch.
    static func observe(_ handler: @escaping @Sendable () -> Void) {
        self.handler = handler
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), nil,
            { _, _, _, _, _ in ChangeNotifier.handler?() },
            name as CFString, nil, .deliverImmediately)
    }
}
