import SwiftUI

/// Дизайн-система Sip: тёмное «жидкое стекло».
enum Theme {
    static let bg = Color(red: 0.027, green: 0.043, blue: 0.078)          // #070B14
    static let bgTop = Color(red: 0.063, green: 0.133, blue: 0.247)       // #10223F
    static let aqua = Color(red: 0.133, green: 0.827, blue: 0.933)        // #22D3EE
    static let deepBlue = Color(red: 0.145, green: 0.388, blue: 0.922)    // #2563EB
    static let indigo = Color(red: 0.388, green: 0.400, blue: 0.945)      // #6366F1
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
