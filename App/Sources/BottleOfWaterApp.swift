import SwiftUI
import SwiftData

@main
struct BottleOfWaterApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(HydrationService.shared.container)
    }
}

/// Three screens in a horizontal pager: History ← Home → Today.
struct RootView: View {
    @State private var page = 1
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Theme.background
            TabView(selection: $page) {
                HistoryView().tag(0)
                HomeView().tag(1)
                TodayView().tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .never))
        }
        .onChange(of: page) {
            UIApplication.dismissKeyboard()
        }
        .onChange(of: scenePhase) {
            // Форс-синхронизация с Apple Health в критических точках:
            // возврат в приложение и уход в фон (flush защищён от повторного входа).
            if scenePhase == .active || scenePhase == .background {
                Task { await HydrationService.shared.flushPendingHealth() }
            }
        }
        .task {
            // Health permission is requested on the first log (see HealthKitService.save)
            ReminderPlanner.rescheduleAll()
            await HydrationService.shared.flushPendingHealth()
        }
    }
}

extension UIApplication {
    /// Global keyboard dismissal (e.g. when swiping between pages).
    static func dismissKeyboard() {
        shared.sendAction(#selector(UIResponder.resignFirstResponder),
                          to: nil, from: nil, for: nil)
    }
}
