import SwiftUI

/// Bottle of Water design system: dark "liquid glass".
enum Theme {
    static let bg = Color(red: 0.027, green: 0.043, blue: 0.078)          // #070B14
    static let bgTop = Color(red: 0.063, green: 0.133, blue: 0.247)       // #10223F
    static let aqua = Color(red: 0.133, green: 0.827, blue: 0.933)        // #22D3EE
    static let sky = Color(red: 0.220, green: 0.741, blue: 0.973)         // #38BDF8
    static let deepBlue = Color(red: 0.145, green: 0.388, blue: 0.922)    // #2563EB
    static let indigo = Color(red: 0.388, green: 0.400, blue: 0.945)      // #6366F1
    static let indigoLight = Color(red: 0.506, green: 0.549, blue: 0.973) // #818CF8
    static let ink = Color(red: 0.016, green: 0.071, blue: 0.110)         // text on bright fills
    static let success = Color(red: 0.290, green: 0.871, blue: 0.502)     // #4ADE80
    static let teal = Color(red: 0.055, green: 0.647, blue: 0.627)        // #0EA5A0
    static let danger = Color(red: 0.984, green: 0.443, blue: 0.522)      // #FB7185
    static let warn = Color(red: 0.984, green: 0.749, blue: 0.141)        // #FBBF24
    static let textPrimary = Color(red: 0.949, green: 0.965, blue: 1.0)   // #F2F6FF
    static let textSecondary = Color(red: 0.604, green: 0.655, blue: 0.741) // #9AA7BD
    static let textTertiary = Color(red: 0.420, green: 0.471, blue: 0.565)  // #6B7890

    static let glass = Color(red: 0.58, green: 0.72, blue: 1.0).opacity(0.07)
    static let glassRaised = Color(red: 0.58, green: 0.72, blue: 1.0).opacity(0.13)
    static let stroke = Color(red: 0.58, green: 0.72, blue: 1.0).opacity(0.14)

    static let primaryGradient = LinearGradient(
        colors: [aqua, indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let liquidGradient = LinearGradient(
        colors: [aqua, deepBlue], startPoint: .top, endPoint: .bottom)
    static let goalGradient = LinearGradient(
        colors: [success, teal], startPoint: .top, endPoint: .bottom)
    static let buttonPrimaryGradient = LinearGradient(
        colors: [aqua, sky], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let buttonSecondaryGradient = LinearGradient(
        colors: [indigoLight, indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let widgetSurface = LinearGradient(
        colors: [Color(red: 0.051, green: 0.102, blue: 0.188),
                 Color(red: 0.075, green: 0.102, blue: 0.227)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

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
    func glassCard(radius: CGFloat = 22) -> some View {
        modifier(GlassCard(radius: radius))
    }

    /// Sheets: the gradient *is* the sheet background, so there's no second layer.
    func themedSheet() -> some View {
        presentationBackground { Theme.background }
    }

    /// Shared look for Form/List screens.
    func themedList() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.background)
    }
}

extension Font {
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .heavy) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.heavy))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Theme.primaryGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}
