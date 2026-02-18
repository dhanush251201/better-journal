//
//  DrawingStorageManager.swift
//  better-journal
//

import UIKit
import PencilKit

/// Manages file-system storage of PKDrawing data and thumbnails.
/// Mirrors the pattern of PhotoStorageManager, storing binary drawing data
/// and pre-rendered JPEG thumbnails.
final class DrawingStorageManager {
    static let shared = DrawingStorageManager()

    private let drawingsDirectory: URL

    private init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        drawingsDirectory = documents.appendingPathComponent("JournalDrawings", isDirectory: true)
        try? FileManager.default.createDirectory(at: drawingsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Save

    /// Serialize and save a PKDrawing to disk.
    func save(drawing: PKDrawing, id: UUID) {
        let data = drawing.dataRepresentation()
        let url = drawingsDirectory.appendingPathComponent("\(id.uuidString).drawing")
        try? data.write(to: url)
    }

    /// Render and save a JPEG thumbnail of the drawing.
    func saveThumbnail(drawing: PKDrawing, id: UUID, canvasSize: CGSize = CGSize(width: 600, height: 400)) {
        let bounds = drawing.bounds
        guard !bounds.isEmpty else { return }

        // Scale to fit within thumbnail size
        let maxDim: CGFloat = 400
        let scale = min(maxDim / bounds.width, maxDim / bounds.height, 1.0)
        let thumbnailSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        let image = drawing.image(from: bounds, scale: scale)

        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
        let thumbnail = renderer.image { ctx in
            // White background for readability
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: thumbnailSize))
            image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        }

        guard let data = thumbnail.jpegData(compressionQuality: 0.7) else { return }
        let url = drawingsDirectory.appendingPathComponent("\(id.uuidString)_thumb.jpg")
        try? data.write(to: url)
    }

    // MARK: - Load

    func loadDrawing(id: UUID) -> PKDrawing? {
        let url = drawingsDirectory.appendingPathComponent("\(id.uuidString).drawing")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PKDrawing(data: data)
    }

    func loadThumbnail(id: UUID) -> UIImage? {
        let url = drawingsDirectory.appendingPathComponent("\(id.uuidString)_thumb.jpg")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Delete

    func delete(id: UUID) {
        let drawingURL = drawingsDirectory.appendingPathComponent("\(id.uuidString).drawing")
        let thumbURL = drawingsDirectory.appendingPathComponent("\(id.uuidString)_thumb.jpg")
        try? FileManager.default.removeItem(at: drawingURL)
        try? FileManager.default.removeItem(at: thumbURL)
    }
}
