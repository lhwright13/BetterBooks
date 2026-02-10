import SwiftUI

// MARK: - echoWright Design System

enum EW {
    // ─── Colors ───
    enum Colors {
        static let teal = Color(red: 0.31, green: 0.74, blue: 0.67)       // #4FBDAB
        static let tealDark = Color(red: 0.23, green: 0.61, blue: 0.55)   // #3A9B8C
        static let tealLight = Color(red: 0.91, green: 0.96, blue: 0.95)  // #E8F6F3

        static let orange = Color(red: 0.96, green: 0.65, blue: 0.14)     // #F5A623
        static let orangeLight = Color(red: 1.0, green: 0.96, blue: 0.88) // #FFF4E0
        static let redOrange = Color(red: 0.88, green: 0.31, blue: 0.22)  // #E04E39

        static let yellow = Color(red: 1.0, green: 0.87, blue: 0.35)      // #FFDE59

        static let background = Color(red: 0.98, green: 0.98, blue: 0.97) // #FAFAF8
        static let surface = Color.white
        static let dark = Color(red: 0.12, green: 0.12, blue: 0.12)       // #1E1E1E
        static let darkSoft = Color(red: 0.23, green: 0.23, blue: 0.23)   // #3A3A3A
        static let gray = Color(red: 0.53, green: 0.53, blue: 0.53)       // #888888
        static let grayLight = Color(red: 0.78, green: 0.78, blue: 0.78)  // #C8C8C8
    }

    // ─── Typography ───
    enum Fonts {
        static func heading(_ size: CGFloat = 22) -> Font {
            .custom("Georgia", size: size).weight(.semibold)
        }

        static func headingBold(_ size: CGFloat = 32) -> Font {
            .custom("Georgia", size: size).weight(.bold)
        }

        static func body(_ size: CGFloat = 15) -> Font {
            .system(size: size, weight: .regular, design: .default)
        }

        static func bodyMedium(_ size: CGFloat = 15) -> Font {
            .system(size: size, weight: .medium, design: .default)
        }

        static func caption(_ size: CGFloat = 13) -> Font {
            .system(size: size, weight: .regular, design: .default)
        }

        static func label(_ size: CGFloat = 12) -> Font {
            .system(size: size, weight: .semibold, design: .default)
        }
    }

    // ─── Spacing ───
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // ─── Radius ───
    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let full: CGFloat = 999
    }
}

// MARK: - Reusable View Modifiers

struct EWCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(EW.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: EW.Radius.md))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

struct EWPrimaryButton: ViewModifier {
    var color: Color = EW.Colors.teal

    func body(content: Content) -> some View {
        content
            .font(EW.Fonts.bodyMedium())
            .foregroundColor(.white)
            .padding(.horizontal, EW.Spacing.lg)
            .padding(.vertical, 14)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: EW.Radius.lg))
    }
}

extension View {
    func ewCard() -> some View {
        modifier(EWCardStyle())
    }

    func ewPrimaryButton(color: Color = EW.Colors.teal) -> some View {
        modifier(EWPrimaryButton(color: color))
    }
}
