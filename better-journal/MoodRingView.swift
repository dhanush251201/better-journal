//
//  MoodRingView.swift
//  better-journal
//

import SwiftUI

/// An animated circular ring that visualizes mood on a spectral gradient.
/// The ring slowly rotates and glows based on valence/arousal.
struct MoodRingView: View {
    let averageValence: Double
    let averageArousal: Double
    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .stroke(
                    AngularGradient(
                        colors: spectrumColors,
                        center: .center
                    ),
                    lineWidth: 14
                )
                .blur(radius: 12)
                .opacity(0.4)
                .scaleEffect(pulseScale)

            // Main ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: spectrumColors,
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )

            // Inner soft fill
            Circle()
                .fill(
                    RadialGradient(
                        colors: [innerColor.opacity(0.15), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 60
                    )
                )

            // Center emoji
            VStack(spacing: 4) {
                Text(moodEmoji)
                    .font(.system(size: 36))

                Text(moodLabel)
                    .font(BJDesign.Typography.moodLabel)
                    .foregroundStyle(.secondary)
            }
        }
        .rotationEffect(.degrees(rotation))
        .onAppear {
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(BJAnimation.breathe) {
                pulseScale = 1.05
            }
        }
    }

    // MARK: - Computed Properties

    private var spectrumColors: [Color] {
        if averageValence > 0.3 {
            return [
                BJDesign.MoodColor.warmAmber,
                BJDesign.MoodColor.softCream,
                BJDesign.MoodColor.seafoam,
                BJDesign.MoodColor.softSky,
                BJDesign.MoodColor.warmAmber
            ]
        } else if averageValence < -0.3 {
            return [
                BJDesign.MoodColor.slate,
                BJDesign.MoodColor.stormGray,
                BJDesign.MoodColor.pewter,
                BJDesign.MoodColor.mist,
                BJDesign.MoodColor.slate
            ]
        } else {
            return [
                BJDesign.MoodColor.softSky,
                BJDesign.MoodColor.seafoam,
                BJDesign.MoodColor.softCream,
                BJDesign.MoodColor.mist,
                BJDesign.MoodColor.softSky
            ]
        }
    }

    private var innerColor: Color {
        if averageValence > 0.3 { return BJDesign.MoodColor.warmAmber }
        if averageValence < -0.3 { return BJDesign.MoodColor.stormGray }
        return BJDesign.MoodColor.softSky
    }

    private var moodEmoji: String {
        if averageValence > 0.5 { return "☀️" }
        if averageValence > 0.2 { return "🌤️" }
        if averageValence > -0.2 { return "⛅" }
        if averageValence > -0.5 { return "🌧️" }
        return "🌩️"
    }

    private var moodLabel: String {
        if averageValence > 0.5 { return "Radiant" }
        if averageValence > 0.2 { return "Bright" }
        if averageValence > -0.2 { return "Balanced" }
        if averageValence > -0.5 { return "Cloudy" }
        return "Stormy"
    }
}

#Preview {
    MoodRingView(averageValence: 0.6, averageArousal: 0.4)
        .frame(width: 200, height: 200)
        .padding()
}
