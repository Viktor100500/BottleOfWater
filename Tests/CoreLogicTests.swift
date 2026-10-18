import Foundation
import Testing
@testable import BottleOfWater

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    calendar.firstWeekday = 2
    return calendar
}()

private func date(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 10) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
}

@Suite("Volume & progress")
struct VolumeTests {
    @Test func ounceRoundTrip() {
        let unit = VolumeUnit.fluidOunces
        #expect(unit.milliliters(from: 8) == 237)
        #expect(abs(unit.value(fromML: 237) - 8.01) < 0.01)
        #expect(VolumeUnit.milliliters.milliliters(from: 250) == 250)
    }

    @Test func percentNeverShows100BeforeGoal() {
        #expect(ProgressMath.percent(total: 1999, goal: 2000) == 99)
        #expect(ProgressMath.percent(total: 2000, goal: 2000) == 100)
        #expect(ProgressMath.percent(total: 3000, goal: 2000) == 150)
        #expect(ProgressMath.percent(total: 0, goal: 2000) == 0)
        #expect(ProgressMath.fraction(total: 3000, goal: 2000) == 1)
    }

    @Test(arguments: [(50.0, 1500), (70.0, 2100), (20.0, 1000), (200.0, 4500)])
    func goalSuggestion(weight: Double, expected: Int) {
        #expect(GoalCalculator.suggestedML(weightKg: weight) == expected)
    }
}

@Suite("Reminder planning")
struct ReminderPlannerTests {
    private func settings(_ configure: (inout ReminderSettings) -> Void = { _ in }) -> ReminderSettings {
        var settings = ReminderSettings()
        settings.isEnabled = true
        settings.intervalMinutes = 120
        settings.windowStart = 9 * 60
        settings.windowEnd = 21 * 60
        configure(&settings)
        return settings
    }

    @Test func disabledPlansNothing() {
        let context = ReminderPlanner.Context(now: date(19, 8), lastLog: nil, todayTotalML: 0, goalML: 2000)
        #expect(ReminderPlanner.plan(settings { $0.isEnabled = false }, context: context, calendar: calendar).isEmpty)
    }

    @Test func intervalGridInsideWindow() {
        let context = ReminderPlanner.Context(now: date(19, 8), lastLog: nil, todayTotalML: 0, goalML: 2000)
        let plan = ReminderPlanner.plan(settings(), context: context, calendar: calendar, horizonDays: 1)
        #expect(plan == [9, 11, 13, 15, 17, 19, 21].map { date(19, $0) })
    }

    @Test func intervalRestartsFromLastDrink() {
        let context = ReminderPlanner.Context(now: date(19, 10, 30), lastLog: date(19, 10, 15),
                                              todayTotalML: 500, goalML: 2000)
        let plan = ReminderPlanner.plan(settings(), context: context, calendar: calendar, horizonDays: 1)
        #expect(plan.first == date(19, 12, 15))
        #expect(plan.last == date(19, 20, 15))
    }

    @Test func goalReachedSkipsRestOfToday() {
        let context = ReminderPlanner.Context(now: date(19, 14), lastLog: date(19, 13),
                                              todayTotalML: 2100, goalML: 2000)
        let plan = ReminderPlanner.plan(settings(), context: context, calendar: calendar, horizonDays: 2)
        #expect(plan.allSatisfy { !calendar.isDate($0, inSameDayAs: date(19, 0)) })
        #expect(plan.first == date(20, 9))

        let keepGoing = ReminderPlanner.plan(settings { $0.skipWhenGoalReached = false },
                                             context: context, calendar: calendar, horizonDays: 1)
        #expect(!keepGoing.isEmpty)
    }

    @Test func specificTimesRespectWeekdaysAndRecentDrink() {
        // 2026-10-19 is a Monday.
        let s = settings {
            $0.mode = .times
            $0.times = [ReminderTime(minutes: 12 * 60, weekdays: Set(2...6)),
                        ReminderTime(minutes: 18 * 60, weekdays: [1, 7])]
        }
        let context = ReminderPlanner.Context(now: date(19, 8), lastLog: nil, todayTotalML: 0, goalML: 2000)
        let plan = ReminderPlanner.plan(s, context: context, calendar: calendar, horizonDays: 7)
        #expect(plan.count == 7)
        #expect(plan.contains(date(24, 18)))   // Saturday
        #expect(!plan.contains(date(24, 12)))

        let afterDrink = ReminderPlanner.Context(now: date(19, 11, 50), lastLog: date(19, 11, 45),
                                                 todayTotalML: 300, goalML: 2000)
        let skipped = ReminderPlanner.plan(s, context: afterDrink, calendar: calendar, horizonDays: 1)
        #expect(skipped.isEmpty)
    }

    @Test func respectsNotificationLimit() {
        let s = settings { $0.intervalMinutes = 30 }
        let context = ReminderPlanner.Context(now: date(19, 0), lastLog: nil, todayTotalML: 0, goalML: 2000)
        #expect(ReminderPlanner.plan(s, context: context, calendar: calendar, limit: 60).count == 60)
    }
}

@Suite("History statistics")
struct HistoryMathTests {
    private let goal = 2000

    private func totals(_ days: [Int: Int]) -> [Date: Int] {
        Dictionary(uniqueKeysWithValues: days.map { (calendar.startOfDay(for: date($0.key, 12)), $0.value) })
    }

    @Test func streakCountsUntilYesterdayWhileTodayInProgress() {
        let data = totals([15: 2000, 16: 2500, 17: 2100, 18: 500])
        #expect(HistoryMath.currentStreak(data, goal: goal, now: date(18, 15), calendar: calendar) == 3)
        #expect(HistoryMath.currentStreak(data, goal: goal, now: date(20, 15), calendar: calendar) == 0)
    }

    @Test func bestStreakFindsLongestRun() {
        let data = totals([1: 2000, 2: 2000, 4: 2000, 5: 2000, 6: 2000, 7: 100])
        #expect(HistoryMath.bestStreak(data, goal: goal, calendar: calendar) == 3)
    }

    @Test func weekBucketsCoverElapsedDaysOnly() {
        let interval = HistoryRange.week.interval(containing: date(14, 12), calendar: calendar)
        let data = totals([12: 1000, 14: 3000])
        let buckets = HistoryMath.buckets(data, interval: interval, component: .day,
                                          now: date(14, 18), calendar: calendar)
        #expect(buckets.count == 3)          // Mon 12 … Wed 14
        #expect(buckets.map(\.totalML) == [1000, 0, 3000])
    }

    @Test func monthlyBucketsAverageByElapsedDays() {
        let interval = HistoryRange.year.interval(containing: date(10, 12), calendar: calendar)
        let data = totals([1: 3000, 2: 3000])
        let buckets = HistoryMath.buckets(data, interval: interval, component: .month,
                                          now: date(10, 12), calendar: calendar)
        let october = buckets.last!
        #expect(october.totalML == 6000)
        #expect(october.averageML == 600)    // 6000 over 10 elapsed days
    }

    @Test func goalDaysAndAverage() {
        let interval = HistoryRange.week.interval(containing: date(14, 12), calendar: calendar)
        let data = totals([12: 2500, 13: 1000, 14: 2000])
        let result = HistoryMath.goalDays(data, interval: interval, goal: goal, now: date(14, 20), calendar: calendar)
        #expect(result.met == 2)
        #expect(result.elapsed == 3)
        #expect(HistoryMath.averageOnLoggedDays(data, interval: interval) == 1833)
    }
}

@Suite("Support")
struct SupportTests {
    private func query(_ url: URL?) throws -> (URLComponents, [String: String]) {
        let components = try #require(url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) })
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        return (components, items)
    }

    @Test func mailAppDraftIsAddressedAndTagged() throws {
        let (components, items) = try query(MailClient.mail.appURL)
        #expect(components.scheme == "mailto")
        #expect(components.path == "yar.thedeveloper@proton.me")
        #expect(items["subject"] == "[Bottle of Water] Feedback")
        #expect(items["body"]?.contains("App: Bottle of Water") == true)
        #expect(MailClient.mail.webURL == nil)
    }

    @Test func gmailOpensAppOrWebComposer() throws {
        let (app, appItems) = try query(MailClient.gmail.appURL)
        #expect(app.url?.absoluteString.hasPrefix("googlegmail:///co?") == true)
        #expect(appItems["to"] == "yar.thedeveloper@proton.me")

        let (web, webItems) = try query(MailClient.gmail.webURL)
        #expect(web.host == "mail.google.com")
        #expect(webItems["view"] == "cm")
        #expect(webItems["su"] == "[Bottle of Water] Feedback")
    }

    @Test func outlookOpensAppOrWebComposer() throws {
        let (app, appItems) = try query(MailClient.outlook.appURL)
        #expect(app.url?.absoluteString.hasPrefix("ms-outlook://compose?") == true)
        #expect(appItems["subject"] == "[Bottle of Water] Feedback")

        let (web, webItems) = try query(MailClient.outlook.webURL)
        #expect(web.host == "outlook.live.com")
        #expect(webItems["to"] == "yar.thedeveloper@proton.me")
    }
}
