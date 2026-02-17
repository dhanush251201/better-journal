//
//  CollageLayout.swift
//  better-journal
//
//  Created by Dhanush Gowdhaman on 2/17/26.
//

import Foundation

enum CollageLayout: String, Codable, CaseIterable {
    case single
    case sideBySide
    case topAndBottom
    case triLayout
    case quadGrid

    var photoCount: Int {
        switch self {
        case .single: return 1
        case .sideBySide, .topAndBottom: return 2
        case .triLayout: return 3
        case .quadGrid: return 4
        }
    }

    var displayName: String {
        switch self {
        case .single: return "Single"
        case .sideBySide: return "Side by Side"
        case .topAndBottom: return "Top & Bottom"
        case .triLayout: return "Three"
        case .quadGrid: return "Grid"
        }
    }

    var iconSystemName: String {
        switch self {
        case .single: return "square"
        case .sideBySide: return "rectangle.split.2x1"
        case .topAndBottom: return "rectangle.split.1x2"
        case .triLayout: return "rectangle.split.2x1.slash"
        case .quadGrid: return "rectangle.split.2x2"
        }
    }
}

struct CollageData: Codable, Equatable {
    var layout: CollageLayout
    var photoIDs: [UUID]

    var isEmpty: Bool {
        photoIDs.isEmpty
    }

    init(layout: CollageLayout = .single, photoIDs: [UUID] = []) {
        self.layout = layout
        self.photoIDs = photoIDs
    }
}
