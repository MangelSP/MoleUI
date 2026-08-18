import SwiftUI
import AppKit

/// MoleUI design system — deep dark surfaces, emerald accent, amber for heat/warnings,
/// monospaced uppercase card labels, big rounded readouts. Tuned to a dense
/// system-monitor aesthetic.
enum Theme {
    // Accents
    static let emerald = Color(red: 0.208, green: 0.784, blue: 0.541)  // #35C88A primary
    static let amber   = Color(red: 0.886, green: 0.643, blue: 0.271)  // #E2A445 heat / warn
    static let danger  = Color(red: 0.898, green: 0.392, blue: 0.361)  // #E5645C
    static let sky     = Color(red: 0.357, green: 0.553, blue: 0.937)  // #5B8DEF disk/net

    /// Window background — deep, faintly warm in dark; soft cream in light.
    static let bg = dyn(dark: (0.055, 0.059, 0.063), light: (0.965, 0.960, 0.945))
    /// Elevated card surface.
    static let surface = dyn(dark: (0.098, 0.105, 0.110), light: (1.0, 0.998, 0.992))
    /// Hairline border.
    static let hairline = Color.white.opacity(0.07)

    static func health(_ s: Int) -> Color { s >= 80 ? emerald : (s >= 50 ? amber : danger) }
    static func load(_ p: Double) -> Color { p < 75 ? emerald : (p < 90 ? amber : danger) }

    private static func dyn(dark: (Double, Double, Double), light: (Double, Double, Double)) -> Color {
        Color(nsColor: NSColor(name: nil) { ap in
            let d = ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let c = d ? dark : light
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}

extension Font {
    /// Rounded display face — big readouts.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    /// Monospaced label face — card headers, data.
    static func monoLabel(_ size: CGFloat = 11, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension View {
    /// The one card container.
    func moleCard(_ padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.hairline))
    }
}

/// A small pill badge (top-right of a card, hardware chips, states).
struct Badge: View {
    let text: String
    var tint: Color = .secondary
    init(_ text: String, tint: Color = .secondary) { self.text = text; self.tint = tint }
    var body: some View {
        Text(text)
            .font(.monoLabel(10))
            .foregroundStyle(tint == .secondary ? AnyShapeStyle(.secondary) : AnyShapeStyle(tint))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(.white.opacity(0.06), in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.hairline))
    }
}
