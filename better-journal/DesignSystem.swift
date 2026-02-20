//
//  DesignSystem.swift
//  better-journal
//

import SwiftUI

// MARK: - Color Palette

extension Color {
    /// Initialize from hex string (e.g. "FFD700")
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

/// Design tokens for the Better Journal app — Headspace-inspired.
enum BJDesign {

    // MARK: - Headspace Palette

    enum Palette {
        /// Warm cream background (adaptive)
        static let cream = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0x1c/255, green: 0x1c/255, blue: 0x1e/255, alpha: 1)  // #1c1c1e
                : UIColor(red: 0xfd/255, green: 0xf5/255, blue: 0xeb/255, alpha: 1)  // #fdf5eb
        })
        /// Primary accent — warm orange
        static let warmOrange  = Color(hex: "f58b44")
        /// Secondary accent — deep coral
        static let deepCoral   = Color(hex: "e8614d")
        /// Text — grounding gray-blue (adaptive)
        static let grayBlue = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0xe5/255, green: 0xe5/255, blue: 0xea/255, alpha: 1)  // #e5e5ea
                : UIColor(red: 0x4b/255, green: 0x51/255, blue: 0x61/255, alpha: 1)  // #4b5161
        })
        /// Soft sand for card backgrounds (adaptive)
        static let sand = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0x2c/255, green: 0x2c/255, blue: 0x2e/255, alpha: 1)  // #2c2c2e
                : UIColor(red: 0xf7/255, green: 0xee/255, blue: 0xd7/255, alpha: 1)  // #f7eed7
        })
        /// Muted lavender for subtle accents
        static let softLavender = Color(hex: "c9b8d9")
    }

    // MARK: - Mood Colors

    enum MoodColor {
        // Positive zone
        static let warmAmber    = Color(hex: "FFD700")
        static let softCream    = Color(hex: "FFF3CD")
        static let warmGlow     = Color(hex: "FFF8E1")
        static let sunsetGold   = Color(hex: "FFECB3")

        // Calm zone
        static let softSky      = Color(hex: "A8D8EA")
        static let mist         = Color(hex: "E8F4FD")
        static let seafoam      = Color(hex: "B2DFDB")

        // Intense zone
        static let coral        = Color(hex: "FF6B6B")
        static let rose         = Color(hex: "FFE3E3")
        static let electricBlue = Color(hex: "448AFF")

        // Negative zone
        static let slate        = Color(hex: "6C7A89")
        static let pewter       = Color(hex: "D5DBDB")
        static let stormGray    = Color(hex: "90A4AE")

        // Neutral (adaptive)
        static let warmGray = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0x2c/255, green: 0x2c/255, blue: 0x2e/255, alpha: 1)  // #2c2c2e
                : UIColor(red: 0xF5/255, green: 0xF5/255, blue: 0xF5/255, alpha: 1)  // #F5F5F5
        })
        static let nearWhite = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0x1c/255, green: 0x1c/255, blue: 0x1e/255, alpha: 1)  // #1c1c1e
                : UIColor(red: 0xFA/255, green: 0xFA/255, blue: 0xFA/255, alpha: 1)  // #FAFAFA
        })
    }

    // MARK: - Typography

    enum Typography {
        static let largeTitle   = Font.system(.largeTitle, design: .rounded, weight: .bold)
        static let title        = Font.system(.title2, design: .rounded, weight: .semibold)
        static let headline     = Font.system(.headline, design: .rounded, weight: .medium)
        static let body         = Font.system(.body, design: .rounded, weight: .regular)
        static let caption      = Font.system(.caption, design: .rounded, weight: .regular)
        static let captionBold  = Font.system(.caption, design: .rounded, weight: .medium)
        static let moodLabel    = Font.system(.caption2, design: .rounded, weight: .semibold)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 12
        static let lg: CGFloat  = 16
        static let xl: CGFloat  = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Corner Radius

    enum Radius {
        static let small: CGFloat  = 10
        static let medium: CGFloat = 16
        static let large: CGFloat  = 20
        static let xlarge: CGFloat = 28
        static let pill: CGFloat   = 100
    }

    // MARK: - Shadows

    enum Shadow {
        static let soft = (color: Color.black.opacity(0.04), radius: CGFloat(12), y: CGFloat(3))
        static let medium = (color: Color.black.opacity(0.07), radius: CGFloat(16), y: CGFloat(5))
        static let glow = (color: Color.black.opacity(0.03), radius: CGFloat(24), y: CGFloat(0))
    }
}

// MARK: - Animation Constants

enum BJAnimation {
    static let springEntry      = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let springGentle     = Animation.spring(response: 0.6, dampingFraction: 0.85)
    static let moodTransition   = Animation.easeInOut(duration: 0.6)
    static let microPulse       = Animation.easeInOut(duration: 0.3)
    static let breathe          = Animation.easeInOut(duration: 4.0).repeatForever(autoreverses: true)
    static let quickFade        = Animation.easeOut(duration: 0.2)
    static let staggerDelay: Double = 0.05
}

// MARK: - View Modifiers

struct BJCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: BJDesign.Radius.large, style: .continuous)
                    .fill(BJDesign.Palette.cream.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: BJDesign.Radius.large, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
            .shadow(
                color: BJDesign.Shadow.soft.color,
                radius: BJDesign.Shadow.soft.radius,
                y: BJDesign.Shadow.soft.y
            )
    }
}

extension View {
    func bjCard() -> some View {
        modifier(BJCardStyle())
    }
}

// MARK: - Haptic Helpers

enum BJHaptic {
    static func success()  { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning()  { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func light()    { UIImpactFeedbackGenerator(style: .light).impactOccurred()  }
    static func soft()     { UIImpactFeedbackGenerator(style: .soft).impactOccurred()   }
    static func heavy()    { UIImpactFeedbackGenerator(style: .heavy).impactOccurred()  }
    static func selection(){ UISelectionFeedbackGenerator().selectionChanged() }

    /// Triple-tap celebration for milestones
    static func celebrate() {
        let gen = UIImpactFeedbackGenerator(style: .heavy)
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) {
                gen.impactOccurred()
            }
        }
    }
}

// MARK: - Insight Color Palette (Premium, Never Harsh)

enum InsightPalette {
    // Joy: warm gold → cream
    static let joyGold     = Color(hex: "FFD700")
    static let joyCream    = Color(hex: "FFF3CD")

    // Calm: soft sky → mist
    static let calmSky     = Color(hex: "A8D8EA")
    static let calmMist    = Color(hex: "E8F4FD")

    // Anxiety: muted amber → peach
    static let anxietyAmber = Color(hex: "FFAB40")
    static let anxietyPeach = Color(hex: "FFE0B2")

    // Frustration: deep coral → rose
    static let coralDeep   = Color(hex: "FF6B6B")
    static let coralRose   = Color(hex: "FFE3E3")

    // Sadness: slate blue → cloud
    static let slateBlue   = Color(hex: "78909C")
    static let slateCloud  = Color(hex: "CFD8DC")

    // Reflective: lavender → lilac
    static let lavender    = Color(hex: "B39DDB")
    static let lilac       = Color(hex: "EDE7F6")

    // Neutral: warm gray
    static let neutralGray = Color(hex: "E0E0E0")
    static let neutralMist = Color(hex: "F5F5F5")

    /// Map a mood category string to its premium color.
    static func color(for mood: String) -> Color {
        switch mood {
        case "happy", "excited", "grateful":  return joyGold
        case "calm", "hopeful":               return calmSky
        case "anxious", "stressed":           return anxietyAmber
        case "frustrated":                    return coralDeep
        case "sad":                           return slateBlue
        case "reflective", "nostalgic":       return lavender
        default:                              return neutralGray
        }
    }

    /// Soft gradient pair for a mood.
    static func gradient(for mood: String) -> [Color] {
        switch mood {
        case "happy", "excited", "grateful":  return [joyGold, joyCream]
        case "calm", "hopeful":               return [calmSky, calmMist]
        case "anxious", "stressed":           return [anxietyAmber, anxietyPeach]
        case "frustrated":                    return [coralDeep, coralRose]
        case "sad":                           return [slateBlue, slateCloud]
        case "reflective", "nostalgic":       return [lavender, lilac]
        default:                              return [neutralGray, neutralMist]
        }
    }

    // MARK: - CanonicalMood typed overloads

    /// Type-safe color for canonical mood.
    static func color(for mood: CanonicalMood) -> Color {
        mood.color
    }

    /// Type-safe gradient for canonical mood.
    static func gradient(for mood: CanonicalMood) -> [Color] {
        mood.gradient
    }
}

// MARK: - Insight Design Tokens

enum InsightDesign {
    static let cardRadius: CGFloat = 24
    static let largeCardRadius: CGFloat = 32
    static let cardPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 28
}

enum InsightAnimation {
    static let gentle = Animation.easeInOut(duration: 0.5)
    static let slow = Animation.easeInOut(duration: 0.6)
    static let cardEntrance = Animation.spring(response: 0.6, dampingFraction: 0.82)
    static let staggerDelay: Double = 0.08
}

// MARK: - Glass Card Modifier

struct BJGlassCardStyle: ViewModifier {
    var radius: CGFloat = InsightDesign.cardRadius

    func body(content: Content) -> some View {
        content
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
            .shadow(
                color: Color.black.opacity(0.05),
                radius: 16, y: 6
            )
            .shadow(
                color: Color.black.opacity(0.02),
                radius: 4, y: 2
            )
    }
}

extension View {
    func bjGlassCard(radius: CGFloat = InsightDesign.cardRadius) -> some View {
        modifier(BJGlassCardStyle(radius: radius))
    }
}
