import SwiftUI

// Design system from the Claude Design handoff ("Arz Radar Redesign"):
// indigo primary, green reserved for gains, Manrope geometric type, oversized
// numbers with muted decimals, colored gradient avatars, underline tabs, flat
// rows, and a full-dark detail screen.

enum Brand {
    static let accent = Color(hex: 0x4B57E0)       // indigo primary
    static let accent2 = Color(hex: 0x6B78F2)
    static let accentSoft = Color(hex: 0xECEEFC)
    static let pos = Color(hex: 0x12B981)          // gains only
    static let neg = Color(hex: 0xF0444C)
    static let negSoft = Color(hex: 0xFDECEC)
    static let posSoft = Color(hex: 0xE5F8F0)

    static let ink = Color(hex: 0x0B0D12)
    static let ink2 = Color(hex: 0x586071)
    static let ink3 = Color(hex: 0x9097A3)
    static let line = Color(hex: 0xEEF0F3)
    static let section = Color(hex: 0xF4F5F8)
    static let screen = Color.white
    static let card = Color.white

    // Dark detail screen
    static let darkBg = Color.black
    static let darkCard = Color(hex: 0x121319)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

// MARK: - Manrope font

enum AppFont {
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Manrope", size: size).weight(weight)
    }
}

extension View {
    /// Apply Manrope at a given size/weight (falls back to system if unavailable).
    func manrope(_ size: CGFloat, _ weight: Font.Weight = .regular) -> some View {
        font(AppFont.font(size, weight))
    }
    func screenPadding() -> some View { padding(.horizontal, 18) }
}

// MARK: - Oversized number with muted decimals

struct MoneyText: View {
    let value: Double
    var fraction: Int = 2
    var suffix: String? = "₺"
    var prefix: String? = nil
    var size: CGFloat = 17
    var color: Color = Brand.ink

    private var parts: (intp: String, dec: String) {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.minimumFractionDigits = fraction
        f.maximumFractionDigits = fraction
        f.numberStyle = .decimal
        let s = f.string(from: value as NSNumber) ?? "\(value)"
        if let r = s.range(of: ",") {
            return (String(s[s.startIndex..<r.lowerBound]), String(s[r.lowerBound...]))
        }
        return (s, "")
    }

    var body: some View {
        let p = parts
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if let prefix {
                Text(prefix).manrope(size * 0.78, .bold).foregroundStyle(color.opacity(0.7))
                    .padding(.trailing, size * 0.06)
            }
            Text(p.intp).manrope(size, .heavy).foregroundStyle(color)
            if !p.dec.isEmpty {
                Text(p.dec).manrope(size * 0.64, .heavy).foregroundStyle(color.opacity(0.42))
            }
            if let suffix {
                Text(suffix).manrope(size * 0.78, .bold).foregroundStyle(color.opacity(0.7))
                    .padding(.leading, size * 0.12)
            }
        }
        .monospacedDigit()
    }
}

// MARK: - Yield (green/red %)

struct YieldText: View {
    let pct: Double?
    var size: CGFloat = 15

    var body: some View {
        if let pct {
            let neg = pct < 0
            Text("%\(neg ? "-" : "")\(abs(pct).formatted(.number.precision(.fractionLength(2))).replacingOccurrences(of: ".", with: ","))")
                .manrope(size, .bold)
                .foregroundStyle(neg ? Brand.neg : Brand.pos)
                .monospacedDigit()
        }
    }
}

// MARK: - Colored gradient avatar

struct GradientAvatar: View {
    let ticker: String
    var size: CGFloat = 44

    private static let overrides: [String: (UInt32, UInt32)] = [
        "LOGO": (0xD04AE0, 0x8B36DB), "AAGYO": (0xC95A4E, 0x9C3B33),
        "BASGZ": (0xDC6A3C, 0xB5472A), "ULKER": (0xCD9A57, 0xA9763A),
        "KCAER": (0xDD8A3B, 0xB86523), "GARAN": (0xC64E4E, 0x9E3636),
        "ESEN": (0xD04AE0, 0x8B36DB), "TUPRS": (0x4E7BC9, 0x37539E),
        "THYAO": (0xC44E78, 0x9E3656), "SISE": (0x4FB0A6, 0x2E827A),
    ]

    private var colors: (Color, Color) {
        if let o = Self.overrides[ticker] { return (Color(hex: o.0), Color(hex: o.1)) }
        var h = 0
        for ch in ticker.unicodeScalars { h = (h * 31 + Int(ch.value)) % 360 }
        return (Color(hue: Double(h) / 360, saturation: 0.55, brightness: 0.58),
                Color(hue: Double((h + 18) % 360) / 360, saturation: 0.60, brightness: 0.42))
    }

    var body: some View {
        let c = colors
        Text(ticker.prefix(2).uppercased())
            .manrope(size * 0.34, .heavy)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [c.0, c.1], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Circle()
            )
            .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
    }
}

// MARK: - Chip (IPO status)

enum ChipTone { case info, pos, mute }

struct Chip: View {
    let text: String
    var tone: ChipTone = .info

    private var colors: (Color, Color) {
        switch tone {
        case .info: return (Brand.accent, Brand.accentSoft)
        case .pos: return (Brand.pos, Brand.posSoft)
        case .mute: return (Brand.ink2, Brand.line)
        }
    }

    var body: some View {
        Text(text)
            .manrope(12, .bold)
            .foregroundStyle(colors.0)
            .padding(.horizontal, 11).padding(.vertical, 5)
            .background(colors.1, in: Capsule())
    }
}

// MARK: - Pill button

enum PillVariant { case solid, soft, ghost, dark }

struct PillButton: View {
    let title: String
    var icon: String? = nil
    var variant: PillVariant = .soft
    var action: () -> Void = {}

    private var fg: Color {
        switch variant {
        case .solid: return .white
        case .soft: return Brand.accent
        case .ghost: return Brand.ink2
        case .dark: return .white
        }
    }
    private var bg: Color {
        switch variant {
        case .solid: return Brand.accent
        case .soft: return Brand.accentSoft
        case .ghost: return Brand.line
        case .dark: return Color.white.opacity(0.1)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let icon { Image(systemName: icon).font(.system(size: 15, weight: .semibold)) }
                Text(title).manrope(14.5, .bold)
            }
            .foregroundStyle(fg)
            .padding(.horizontal, 18).padding(.vertical, 11)
            .background(bg, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Underline tabs

struct UnderlineTabs<T: Hashable>: View {
    @Binding var selection: T
    let options: [(T, String)]
    var dark: Bool = false

    var body: some View {
        HStack(spacing: 22) {
            ForEach(options, id: \.0) { value, label in
                VStack(spacing: 11) {
                    Text(label)
                        .manrope(15.5, .bold)
                        .foregroundStyle(selection == value
                            ? (dark ? .white : Brand.ink)
                            : Brand.ink3)
                    Rectangle()
                        .fill(selection == value ? Brand.accent : .clear)
                        .frame(height: 2.5)
                        .clipShape(Capsule())
                }
                .fixedSize()
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.easeInOut(duration: 0.18)) { selection = value } }
            }
            Spacer(minLength: 0)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Brand.line).frame(height: 1)
        }
    }
}
