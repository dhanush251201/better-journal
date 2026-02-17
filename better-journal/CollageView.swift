//
//  CollageView.swift
//  better-journal
//
//  Created by Dhanush Gowdhaman on 2/17/26.
//

import SwiftUI
import PhotosUI

// MARK: - Collage Editor (Interactive)

struct CollageEditorView: View {
    @Binding var collageData: CollageData

    @State private var loadedImages: [UUID: UIImage] = [:]
    @State private var selectedSlotIndex: Int?
    @State private var showSourcePicker = false
    @State private var showCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 8) {
            collageContent
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

            if !collageData.isEmpty {
                templatePicker
            }
        }
        .onAppear(perform: loadImages)
        .confirmationDialog("Add Photo", isPresented: $showSourcePicker) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Text("Photo Library")
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Camera") { showCamera = true }
            }
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    addImage(image)
                }
                selectedPhotoItem = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                addImage(image)
            }
        }
    }

    @ViewBuilder
    private var collageContent: some View {
        if collageData.isEmpty {
            emptyPlaceholder
        } else {
            collageGrid
        }
    }

    private var emptyPlaceholder: some View {
        Button {
            selectedSlotIndex = 0
            showSourcePicker = true
        } label: {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .foregroundStyle(.secondary)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                        Text("Add Photos")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.secondary)
                }
        }
    }

    @ViewBuilder
    private var collageGrid: some View {
        let layout = collageData.layout
        let ids = collageData.photoIDs

        switch layout {
        case .single:
            photoSlot(index: 0, ids: ids)

        case .sideBySide:
            HStack(spacing: 2) {
                photoSlot(index: 0, ids: ids)
                photoSlot(index: 1, ids: ids)
            }

        case .topAndBottom:
            VStack(spacing: 2) {
                photoSlot(index: 0, ids: ids)
                photoSlot(index: 1, ids: ids)
            }

        case .triLayout:
            HStack(spacing: 2) {
                photoSlot(index: 0, ids: ids)
                VStack(spacing: 2) {
                    photoSlot(index: 1, ids: ids)
                    photoSlot(index: 2, ids: ids)
                }
            }

        case .quadGrid:
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    photoSlot(index: 0, ids: ids)
                    photoSlot(index: 1, ids: ids)
                }
                HStack(spacing: 2) {
                    photoSlot(index: 2, ids: ids)
                    photoSlot(index: 3, ids: ids)
                }
            }
        }
    }

    @ViewBuilder
    private func photoSlot(index: Int, ids: [UUID]) -> some View {
        if index < ids.count, let image = loadedImages[ids[index]] {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedSlotIndex = index
                    showSourcePicker = true
                }
        } else {
            Button {
                selectedSlotIndex = index
                showSourcePicker = true
            } label: {
                Color(.systemGray5)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }

    private var templatePicker: some View {
        HStack(spacing: 12) {
            ForEach(CollageLayout.allCases, id: \.self) { layout in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        collageData.layout = layout
                        trimOrPadPhotoIDs()
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: layout.iconSystemName)
                            .font(.title3)
                        Text(layout.displayName)
                            .font(.caption2)
                    }
                    .foregroundStyle(collageData.layout == layout ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func loadImages() {
        for id in collageData.photoIDs {
            if loadedImages[id] == nil {
                loadedImages[id] = PhotoStorageManager.shared.loadImage(id: id)
            }
        }
    }

    private func addImage(_ image: UIImage) {
        let id = UUID()
        PhotoStorageManager.shared.save(image: image, id: id)
        PhotoStorageManager.shared.saveThumbnail(image: image, id: id)
        loadedImages[id] = image

        guard let slotIndex = selectedSlotIndex else { return }

        if slotIndex < collageData.photoIDs.count {
            // Replace existing slot
            let oldID = collageData.photoIDs[slotIndex]
            PhotoStorageManager.shared.deleteImage(id: oldID)
            loadedImages.removeValue(forKey: oldID)
            collageData.photoIDs[slotIndex] = id
        } else {
            // Append to fill the next slot
            collageData.photoIDs.append(id)
        }

        selectedSlotIndex = nil
    }

    private func trimOrPadPhotoIDs() {
        let needed = collageData.layout.photoCount
        if collageData.photoIDs.count > needed {
            let removed = collageData.photoIDs[needed...]
            collageData.photoIDs = Array(collageData.photoIDs.prefix(needed))
            for id in removed {
                PhotoStorageManager.shared.deleteImage(id: id)
                loadedImages.removeValue(forKey: id)
            }
        }
    }
}

// MARK: - Collage Display (Read-Only)

struct CollageDisplayView: View {
    let collageData: CollageData
    let height: CGFloat

    @State private var thumbnails: [UUID: UIImage] = [:]

    var body: some View {
        collageGrid
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onAppear {
                for id in collageData.photoIDs {
                    if thumbnails[id] == nil {
                        thumbnails[id] = PhotoStorageManager.shared.loadThumbnail(id: id)
                    }
                }
            }
    }

    @ViewBuilder
    private var collageGrid: some View {
        let ids = collageData.photoIDs

        switch collageData.layout {
        case .single:
            thumbView(index: 0, ids: ids)

        case .sideBySide:
            HStack(spacing: 1) {
                thumbView(index: 0, ids: ids)
                thumbView(index: 1, ids: ids)
            }

        case .topAndBottom:
            VStack(spacing: 1) {
                thumbView(index: 0, ids: ids)
                thumbView(index: 1, ids: ids)
            }

        case .triLayout:
            HStack(spacing: 1) {
                thumbView(index: 0, ids: ids)
                VStack(spacing: 1) {
                    thumbView(index: 1, ids: ids)
                    thumbView(index: 2, ids: ids)
                }
            }

        case .quadGrid:
            VStack(spacing: 1) {
                HStack(spacing: 1) {
                    thumbView(index: 0, ids: ids)
                    thumbView(index: 1, ids: ids)
                }
                HStack(spacing: 1) {
                    thumbView(index: 2, ids: ids)
                    thumbView(index: 3, ids: ids)
                }
            }
        }
    }

    @ViewBuilder
    private func thumbView(index: Int, ids: [UUID]) -> some View {
        if index < ids.count, let image = thumbnails[ids[index]] {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
        } else {
            Color(.systemGray5)
        }
    }
}
