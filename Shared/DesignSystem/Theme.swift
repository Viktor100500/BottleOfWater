import SwiftUI

/// Дизайн-система Sip: тёмное «жидкое стекло».
enum Theme {
    enum Widget {
        static let ink = Theme.ink                                      // dark text on bright buttons
        static let white = Theme.textPrimary                            // #F2F6FF
        static let dim = Theme.textSecondary                            // fixed secondary
        static let aqua = Theme.aqua
        static let blue = Theme.deepBlue
        static let indigo = Theme.indigo
        static let danger = Theme.danger

        static let brandGradient = LinearGradient(colors: [aqua, indigo],
                                                  startPoint: .leading, endPoint: .trailing)
        static let liquidGradient = LinearGradient(colors: [aqua, blue],
                                                   startPoint: .top, endPoint: .bottom)
        static let surface = LinearGradient(
            colors: [Color(red: 0.051, green: 0.102, blue: 0.188),
                     Color(red: 0.075, green: 0.102, blue: 0.227)],
            startPoint: .topLeading, endPoint: .bottomTrailing)

        // Кнопки виджета — карточка «Виджеты» дизайн-системы:
        // .wbtn  = aqua → sky 135°,  .wbtn.alt = indigo light → indigo 135°
        static let buttonPrimaryGradient = LinearGradient(
            colors: [aqua, Theme.sky], startPoint: .topLeading, endPoint: .bottomTrailing)
        static let buttonSecondaryGradient = LinearGradient(
            colors: [Theme.indigoLight, indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let bg = Color(red: 0.027, green: 0.043, blue: 0.078)          // #070B14
    static let bgTop = Color(red: 0.063, green: 0.133, blue: 0.247)       // #10223F
    static let aqua = Color(red: 0.133, green: 0.827, blue: 0.933)        // #22D3EE
    static let sky = Color(red: 0.220, green: 0.741, blue: 0.973)         // #38BDF8 — градиент кнопок виджета
    static let deepBlue = Color(red: 0.145, green: 0.388, blue: 0.922)    // #2563EB
    static let indigo = Color(red: 0.388, green: 0.400, blue: 0.945)      // #6366F1
    static let indigoLight = Color(red: 0.506, green: 0.549, blue: 0.973) // #818CF8 — grad/liquid, кнопки виджета
    static let violet = Color(red: 0.655, green: 0.545, blue: 0.980)      // #A78BFA
    static let ink = Color(red: 0.016, green: 0.071, blue: 0.110)         // тёмный текст на ярких заливках
    static let success = Color(red: 0.290, green: 0.871, blue: 0.502)     // #4ADE80
    static let danger = Color(red: 0.984, green: 0.443, blue: 0.522)      // #FB7185
    static let warn = Color(red: 0.984, green: 0.749, blue: 0.141)        // #FBBF24
    static let textPrimary = Color(red: 0.949, green: 0.965, blue: 1.0)   // #F2F6FF
    static let textSecondary = Color(red: 0.604, green: 0.655, blue: 0.741) // #9AA7BD
    static let textTertiary = Color(red: 0.361, green: 0.408, blue: 0.502)  // #5C6880

    static let glass = Color(red: 0.58, green: 0.72, blue: 1.0).opacity(0.06)
    static let glassRaised = Color(red: 0.58, green: 0.72, blue: 1.0).opacity(0.12)
    static let stroke = Color(red: 0.58, green: 0.72, blue: 1.0).opacity(0.14)

    static let primaryGradient = LinearGradient(
        colors: [aqua, indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let liquidGradient = LinearGradient(
        colors: [aqua, deepBlue], startPoint: .top, endPoint: .bottom)
    static let goalGradient = LinearGradient(
        colors: [success, Color(red: 0.055, green: 0.647, blue: 0.627)],
        startPoint: .top, endPoint: .bottom)

    static var background: some View {
        RadialGradient(colors: [bgTop, bg], center: .init(x: 0.5, y: -0.1),
                       startRadius: 0, endRadius: 700)
        .ignoresSafeArea()
    }
}

struct GlassCard: ViewModifier {
    var radius: CGFloat = 22
    func body(content: Content) -> some View {
        content
            .background(Theme.glass, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1))
    }
}

extension View {
    func glassCard(radius: CGFloat = 22) -> some View { modifier(GlassCard(radius: radius)) }
}
