//
//  PhotoStorageManager.swift
//  better-journal
//
//  Created by Dhanush Gowdhaman on 2/17/26.
//

import UIKit

final class PhotoStorageManager {
    static let shared = PhotoStorageManager()

    private let photosDirectory: URL

    private init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        photosDirectory = documents.appendingPathComponent("JournalPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Save

    func save(image: UIImage, id: UUID) {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        let url = photosDirectory.appendingPathComponent("\(id.uuidString).jpg")
        try? data.write(to: url)
    }

    func saveThumbnail(image: UIImage, id: UUID) {
        let maxDimension: CGFloat = 300
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        guard let data = thumbnail.jpegData(compressionQuality: 0.7) else { return }
        let url = photosDirectory.appendingPathComponent("\(id.uuidString)_thumb.jpg")
        try? data.write(to: url)
    }

    // MARK: - Load

    func loadImage(id: UUID) -> UIImage? {
        let url = photosDirectory.appendingPathComponent("\(id.uuidString).jpg")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func loadThumbnail(id: UUID) -> UIImage? {
        let url = photosDirectory.appendingPathComponent("\(id.uuidString)_thumb.jpg")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Delete

    func deleteImage(id: UUID) {
        let fullURL = photosDirectory.appendingPathComponent("\(id.uuidString).jpg")
        let thumbURL = photosDirectory.appendingPathComponent("\(id.uuidString)_thumb.jpg")
        try? FileManager.default.removeItem(at: fullURL)
        try? FileManager.default.removeItem(at: thumbURL)
    }

    func deleteImages(ids: [UUID]) {
        for id in ids {
            deleteImage(id: id)
        }
    }
}
