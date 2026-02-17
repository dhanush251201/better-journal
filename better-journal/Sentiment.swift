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
        case .happy: return .yellow
        case .grateful: return .pink
        case .calm: return .mint
        case .excited: return .orange
        case .hopeful: return .cyan
        case .reflective: return .indigo
        case .nostalgic: return .purple
        case .anxious: return .gray
        case .sad: return .blue
        case .frustrated: return .red
        case .stressed: return .orange
        case .neutral: return .gray
        }
    }
}

struct SentimentTagView: View {
    let sentiment: Sentiment

    var body: some View {
        Label(sentiment.displayName, systemImage: sentiment.iconName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(sentiment.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(sentiment.color.opacity(0.15), in: Capsule())
    }
}
