import SwiftUI
import UIKit

// One quiet palette, dark-first like Oura, with a single accent and a
// feeling scale that runs from clay (heavier) through stone to sage (lighter).
enum Palette {
    static let paper      = Color(light: 0xF7F5F1, dark: 0x0E0F11)
    static let card       = Color(light: 0xFFFFFF, dark: 0x18191C)
    static let raised     = Color(light: 0xEFEBE5, dark: 0x222327)
    static let ink        = Color(light: 0x1B1A18, dark: 0xECE9E3)
    static let ink2       = Color(light: 0x6B6660, dark: 0xA19C94)
    static let ink3       = Color(light: 0x9A948B, dark: 0x6F6A63)
    static let line       = Color(light: 0xE5E0D9, dark: 0x2A2B2F)
    static let accent     = Color(light: 0x2C5F5A, dark: 0x7FB6AC)
    static let accentSoft = Color(light: 0xE4EDEB, dark: 0x1B2A28)

    private static let heavy = (light: UInt32(0xA4553A), dark: UInt32(0xD9936A))
    private static let even  = (light: UInt32(0x8C877F), dark: UInt32(0x8A857D))
    private static let light = (light: UInt32(0x3F7A5C), dark: UInt32(0x8CC4A0))

    /// -1 (heavy) … 0 (even) … +1 (light)
    static func feeling(_ value: Double) -> Color {
        let v = max(-1, min(1, value))
        return Color(uiColor: UIColor { traits in
            let dark = traits.userInterfaceStyle == .dark
            let mid = UIColor(hex: dark ? even.dark : even.light)
            let end = v < 0
                ? UIColor(hex: dark ? heavy.dark : heavy.light)
                : UIColor(hex: dark ? light.dark : light.light)
            return mid.mixed(with: end, by: abs(v))
        })
    }
}

enum Feeling {
    static func word(_ value: Double?) -> String {
        guard let v = value else { return "unread" }
        switch v {
        case ..<(-0.5): return "heavy"
        case ..<(-0.15): return "low"
        case ..<0.15: return "even"
        case ..<0.5: return "light"
        default: return "bright"
        }
    }
}

extension Font {
    static let display   = Font.system(size: 34, weight: .regular, design: .serif)
    static let headline2 = Font.system(size: 24, weight: .regular, design: .serif)
    static let reading   = Font.system(size: 18, weight: .regular, design: .serif)
    static let bigNumber = Font.system(size: 30, weight: .light, design: .rounded)
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }

    func mixed(with other: UIColor, by t: Double) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = CGFloat(max(0, min(1, t)))
        return UIColor(red: r1 + (r2 - r1) * t,
                       green: g1 + (g2 - g1) * t,
                       blue: b1 + (b2 - b1) * t,
                       alpha: a1 + (a2 - a1) * t)
    }
}
