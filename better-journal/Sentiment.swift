//
//  Sentiment.swift
//  better-journal
//
//  Created by Dhanush Gowdhaman on 2/17/26.
//

import Foundation
import FoundationModels
import SwiftUI

@Generable
enum Sentiment: String, Codable, CaseIterable {
    case happy
    case grateful
    case calm
    case excited
    case hopeful
    case reflective
    case nostalgic
    case anxious
    case sad
    case frustrated
    case stressed
    case neutral

    var displayName: String {
        switch self {
        case .happy: return "Happy"
        case .grateful: return "Grateful"
        case .calm: return "Calm"
        case .excited: return "Excited"
        case .hopeful: return "Hopeful"
        case .reflective: return "Reflective"
        case .nostalgic: return "Nostalgic"
        case .anxious: return "Anxious"
        case .sad: return "Sad"
        case .frustrated: return "Frustrated"
        case .stressed: return "Stressed"
        case .neutral: return "Neutral"
        }
    }

    var iconName: String {
        switch self {
        case .happy: return "sun.max.fill"
        case .grateful: return "heart.fill"
        case .calm: return "leaf.fill"
        case .excited: return "bolt.fill"
        case .hopeful: return "sparkles"
        case .reflective: return "bubble.left.and.bubble.right.fill"
        case .nostalgic: return "clock.arrow.circlepath"
        case .anxious: return "wind"
        case .sad: return "cloud.rain.fill"
        case .frustrated: return "flame.fill"
        case .stressed: return "exclamationmark.triangle.fill"
        case .neutral: return "minus.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .happy: return Color(hex: "FFD700")       // Golden yellow
        case .grateful: return Color(hex: "E88DA1")     // Rose pink
        case .calm: return Color(hex: "6BC5D2")         // Soft teal
        case .excited: return Color(hex: "F58B44")      // Warm orange
        case .hopeful: return Color(hex: "76C7A0")      // Sage green
        case .reflective: return Color(hex: "8B7EC8")   // Warm indigo
        case .nostalgic: return Color(hex: "C49BBD")    // Dusty mauve
        case .anxious: return Color(hex: "E8A838")      // Amber
        case .sad: return Color(hex: "5B8DB8")          // Steel blue
        case .frustrated: return Color(hex: "E8614D")   // Deep coral
        case .stressed: return Color(hex: "C97B5D")     // Burnt sienna
        case .neutral: return Color(hex: "9BA3AF")      // Cool gray
        }
    }

    // MARK: - Valence / Arousal Mapping

    /// Returns (valence, arousal) for this sentiment.
    /// Valence: -1.0 (negative) … 1.0 (positive)
    /// Arousal:  0.0 (calm) … 1.0 (energetic)
    var valenceArousal: (Double, Double) {
        switch self {
        case .happy:       return ( 0.8,  0.6)
        case .grateful:    return ( 0.7,  0.3)
        case .calm:        return ( 0.4,  0.1)
        case .excited:     return ( 0.7,  0.9)
        case .hopeful:     return ( 0.5,  0.4)
        case .reflective:  return ( 0.1,  0.2)
        case .nostalgic:   return ( 0.0,  0.3)
        case .anxious:     return (-0.5,  0.7)
        case .sad:         return (-0.7,  0.2)
        case .frustrated:  return (-0.6,  0.8)
        case .stressed:    return (-0.4,  0.8)
        case .neutral:     return ( 0.0,  0.3)
        }
    }

    /// Map dimensional valence/arousal back to the nearest categorical sentiment.
    static func fromValenceArousal(valence: Double, arousal: Double) -> Sentiment {
        var bestMatch: Sentiment = .neutral
        var bestDistance = Double.greatestFiniteMagnitude

        for sentiment in Sentiment.allCases {
            let (v, a) = sentiment.valenceArousal
            let dist = (v - valence) * (v - valence) + (a - arousal) * (a - arousal)
            if dist < bestDistance {
                bestDistance = dist
                bestMatch = sentiment
            }
        }

        return bestMatch
    }
}

struct SentimentTagView: View {
    let sentiment: Sentiment
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            Label(sentiment.displayName, systemImage: sentiment.iconName)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(sentiment.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(sentiment.color.opacity(0.12))
                        .overlay(
                            Capsule()
                                .strokeBorder(sentiment.color.opacity(0.25), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
