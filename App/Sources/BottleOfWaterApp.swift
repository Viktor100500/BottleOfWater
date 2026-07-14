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
        .task {
            // Health permission is requested on the first log (see HealthKitService.save)
            ReminderPlanner.rescheduleAll()
        }
    }
}
