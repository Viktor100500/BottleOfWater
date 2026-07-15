import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query private var todayEntries: [WaterEntry]

    @State private var customText = ""
    @State private var showSettings = false
    @State private var showReminders = false
    @FocusState private var customFocused: Bool

    @AppStorage("goalML", store: BottleShared.defaults) private var goalML = 2000
    @AppStorage("useOunces", store: BottleShared.defaults) private var useOunces = false

    init() {
        let start = Calendar.current.startOfDay(for: .now)
        _todayEntries = Query(
            filter: #Predicate<WaterEntry> { $0.timestamp >= start },
            sort: [SortDescriptor(\WaterEntry.timestamp, order: .reverse)]
        )
    }

    private var totalToday: Int { todayEntries.reduce(0) { $0 + $1.volumeML } }
    private var presets: [VolumePreset] { SettingsStore.presets }
    private var customVolume: Int? {
        guard let v = Int(customText.trimmingCharacters(in: .whitespaces)),
              v > 0, v <= 5000 else { return nil }
        return v
    }

    var body: some View {
        // minHeight = высота экрана: без клавиатуры раскладка со Spacer'ами как раньше;
        // с клавиатурой область сжимается и контент прокручивается к полю ввода.
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        header
                        Spacer(minLength: 8)
                        LiquidGauge(totalML: totalToday, goalML: max(500, goalML), useOunces: useOunces)
                        undoButton
                            .padding(.top, 10)
                        Spacer(minLength: 8)
                        presetGrid
                        customRow
                            .id("customRow")
                            .padding(.top, 12)
                        tip
                            .padding(.top, 14)
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 20)
                    .frame(minHeight: geo.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: customFocused) {
                    guard customFocused else { return }
                    // Ждём анимацию клавиатуры и докручиваем поле + кнопку выше неё
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo("customRow", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { customFocused = false }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showReminders) { RemindersView() }
    }

    private var header: some View {
        HStack {
            iconButton("gearshape.fill") { showSettings = true }
            Spacer()
            VStack(spacing: 2) {
                Text(verbatim: "Bottle of Water")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.primaryGradient)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("every sip counts")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            iconButton("bell.fill") { showReminders = true }
        }
        .padding(.top, 6)
    }

    private func iconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 42, height: 42)
                .background(Theme.glassRaised, in: Circle())
                .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
        }
    }

    @ViewBuilder
    private var undoButton: some View {
        if let last = todayEntries.first {
            Button {
                Task { await HydrationService.shared.undoLastToday() }
            } label: {
                Label("Undo last (\(VolumeFormatter.string(ml: last.volumeML)))",
                      systemImage: "arrow.uturn.backward")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.danger)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Theme.danger.opacity(0.10), in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.danger.opacity(0.28), lineWidth: 1))
            }
            .transition(.scale.combined(with: .opacity))
        } else {
            // Keeps the layout height stable
            Color.clear.frame(height: 36)
        }
    }

    private var presetGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                  spacing: 10) {
            ForEach(presets) { preset in
                Button {
                    log(preset.volumeML)
                } label: {
                    VStack(spacing: 3) {
                        Text(preset.emoji).font(.system(size: 18))
                        Text(useOunces
                             ? VolumeFormatter.string(ml: preset.volumeML)
                             : "\(preset.volumeML)")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                        Text(preset.name)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        LinearGradient(colors: [Theme.glassRaised, Theme.glass],
                                       startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private var customRow: some View {
        HStack(spacing: 10) {
            TextField("Custom volume, ml", text: $customText)
                .keyboardType(.numberPad)
                .focused($customFocused)
                .font(.body)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Theme.glass, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1))

            Button {
                if let v = customVolume {
                    log(v)
                    customText = ""
                    customFocused = false
                }
            } label: {
                Text("Add")
                    .font(.body.weight(.heavy))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Theme.primaryGradient,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(customVolume == nil)
            .opacity(customVolume == nil ? 0.45 : 1)
        }
    }

    @ViewBuilder
    private var tip: some View {
        if totalToday > 0 {
            Text(HydrationTips.current)
                .font(.caption)
                .foregroundStyle(Theme.aqua.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
        }
    }

    private func log(_ volume: Int) {
        withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
            let entry = HydrationService.shared.log(volumeML: volume, source: .app)
            Task { await HydrationService.shared.syncToHealth(entry) }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}
