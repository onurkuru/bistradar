import SwiftUI

// Midas-inspired design system: clean cards on a soft background, a warm coral
// brand accent, big bold numbers, monogram avatars, and colored percentage pills.

enum Brand {
    static let accent = Color(red: 0.93, green: 0.27, blue: 0.30)   // coral/salmon
    static let positive = Color(red: 0.10, green: 0.72, blue: 0.50)
    static let negative = Color(red: 0.93, green: 0.27, blue: 0.32)

    static let bg = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemGroupedBackground)

    static let gradient = LinearGradient(
        colors: [Color(red: 0.95, green: 0.36, blue: 0.27), Color(red: 0.90, green: 0.18, blue: 0.35)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

/// Rounded elevated card container used across the app.
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }
}

/// Circular monogram avatar from a ticker (first 2 letters), Midas-style.
struct TickerAvatar: View {
    let ticker: String
    var size: CGFloat = 44

    private var monogram: String {
        let t = ticker.isEmpty ? "?" : ticker
        return String(t.prefix(2)).uppercased()
    }

    private var hue: Double {
        // Deterministic pastel from the ticker so each stock has a stable color.
        let sum = ticker.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Double(sum % 360) / 360.0
    }

    var body: some View {
        Text(monogram)
            .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: [
                            Color(hue: hue, saturation: 0.55, brightness: 0.85),
                            Color(hue: hue, saturation: 0.65, brightness: 0.68),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            )
    }
}

/// Small colored pill, e.g. yield % or days-left.
struct Pill: View {
    let text: String
    var color: Color = Brand.accent

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color.opacity(0.14))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

extension View {
    /// Standard horizontal screen padding for scroll content.
    func screenPadding() -> some View { padding(.horizontal, 16) }
}
