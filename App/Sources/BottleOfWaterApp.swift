import BackgroundTasks
import SwiftUI
import UserNotifications

@main
struct BottleOfWaterApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var preferences: Preferences

    init() {
        #if DEBUG
        DemoData.seedIfRequested()
        #endif
        _preferences = State(initialValue: Preferences())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(preferences)
                .environment(WaterStore.shared)
                .preferredColorScheme(.dark)
                .tint(Theme.aqua)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                WaterStore.shared.externalChange()
                Task { await AppLifecycle.refresh() }
            case .background:
                BackgroundRefresh.schedule()
            default:
                break
            }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.taskID)) {
            await AppLifecycle.refresh()
            BackgroundRefresh.schedule()
        }
    }
}

@MainActor
enum AppLifecycle {
    /// Catch-up work for launch, activation and background refresh.
    static func refresh() async {
        await WaterStore.shared.flushPendingHealth()
        await ReminderScheduler.reschedule()
    }
}

enum BackgroundRefresh {
    static let taskID = "com.vlasov.bottleofwater.refresh"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        ReminderScheduler.registerCategories()
        ChangeNotifier.observe {
            Task { @MainActor in WaterStore.shared.externalChange() }
        }
        return true
    }

    /// "+250 mL" tapped on a reminder — the app is launched in the background.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        guard let ml = ReminderScheduler.volume(fromAction: response.actionIdentifier) else { return }
        await WaterStore.shared.log(ml: ml, source: .notification)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

enum AppTab: Hashable {
    case today, history, settings
}

struct RootView: View {
    @Environment(Preferences.self) private var preferences
    @State private var tab: AppTab = DemoData.initialTab

    var body: some View {
        if preferences.onboardingCompleted {
            TabView(selection: $tab) {
                Tab("Today", systemImage: "drop.fill", value: .today) {
                    TodayScreen()
                }
                Tab("History", systemImage: "chart.bar.fill", value: .history) {
                    HistoryScreen()
                }
                Tab("Settings", systemImage: "gearshape.fill", value: .settings) {
                    SettingsScreen()
                }
            }
            .task {
                await AppLifecycle.refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                // Midnight, time zone or clock change: "today" moves, so re-read and replan.
                WaterStore.shared.externalChange()
                Task { await ReminderScheduler.reschedule() }
            }
        } else {
            OnboardingView()
                .transition(.opacity)
        }
    }
}
