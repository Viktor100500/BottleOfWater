import Foundation

/// Ways to write to support. Many people never set up Apple Mail, so the app offers
/// Gmail and Outlook too: their app when installed, otherwise the web composer.
enum MailClient: String, CaseIterable, Identifiable, Sendable {
    case gmail, outlook, mail

    var id: Self { self }

    /// Native app compose URL (needs the scheme in LSApplicationQueriesSchemes).
    var appURL: URL? {
        let (subject, body) = SupportMail.draft
        switch self {
        case .gmail:
            return SupportMail.url("googlegmail", host: "", path: "/co",
                                   ["to": AppInfo.supportEmail, "subject": subject, "body": body])
        case .outlook:
            return SupportMail.url("ms-outlook", host: "compose", path: "",
                                   ["to": AppInfo.supportEmail, "subject": subject, "body": body])
        case .mail:
            return SupportMail.url("mailto", host: nil, path: AppInfo.supportEmail,
                                   ["subject": subject, "body": body])
        }
    }

    /// Browser fallback when the app isn't installed.
    var webURL: URL? {
        let (subject, body) = SupportMail.draft
        switch self {
        case .gmail:
            return SupportMail.url("https", host: "mail.google.com", path: "/mail/",
                                   ["view": "cm", "fs": "1", "to": AppInfo.supportEmail, "su": subject, "body": body])
        case .outlook:
            return SupportMail.url("https", host: "outlook.live.com", path: "/mail/0/deeplink/compose",
                                   ["to": AppInfo.supportEmail, "subject": subject, "body": body])
        case .mail:
            return nil
        }
    }
}

enum SupportMail {
    /// Subject tags the app (one developer mailbox for all apps); the body carries
    /// version info the user can see and edit before sending.
    static var draft: (subject: String, body: String) {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let body = "\n\n—\nApp: Bottle of Water \(AppInfo.version)\n"
            + "iOS: \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)\n"
            + "Device: \(AppInfo.deviceModel)"
        return (AppInfo.supportSubject, body)
    }

    static func url(_ scheme: String, host: String?, path: String, _ query: KeyValuePairs<String, String>) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = path
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        // "+" means a space to some web composers; encode it explicitly.
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        return components.url
    }
}
