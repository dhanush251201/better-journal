//
//  DrawingCanvasView.swift
//  better-journal
//

import SwiftUI
import PencilKit

/// A beautiful PencilKit canvas wrapper with Apple Pencil support,
/// tool picker integration, and undo/redo.
struct DrawingCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    let isEditable: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.delegate = context.coordinator
        canvas.overrideUserInterfaceStyle = .light

        // Default tool
        canvas.tool = PKInkingTool(.pen, color: .darkGray, width: 3)

        if isEditable {
            let toolPicker = PKToolPicker()
            toolPicker.setVisible(true, forFirstResponder: canvas)
            toolPicker.addObserver(canvas)
            context.coordinator.toolPicker = toolPicker
            DispatchQueue.main.async {
                canvas.becomeFirstResponder()
            }
        }

        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        if canvas.drawing != drawing {
            canvas.drawing = drawing
        }
    }

    static func dismantleUIView(_ canvas: PKCanvasView, coordinator: Coordinator) {
        // Hide tool picker and resign first responder to prevent
        // the floating pen/stylus toolbar from lingering after exit
        if let toolPicker = coordinator.toolPicker {
            toolPicker.setVisible(false, forFirstResponder: canvas)
            toolPicker.removeObserver(canvas)
        }
        coordinator.toolPicker = nil
        canvas.resignFirstResponder()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var drawing: Binding<PKDrawing>
        var toolPicker: PKToolPicker?

        init(drawing: Binding<PKDrawing>) {
            self.drawing = drawing
        }

        deinit {
            toolPicker = nil
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing.wrappedValue = canvasView.drawing
        }
    }
}

// MARK: - Drawing Editor Container

/// Full-screen drawing editor with tool bar, undo/redo, and clear actions.
struct DrawingEditorView: View {
    @Binding var drawing: PKDrawing
    @State private var canvasView = PKCanvasView()

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 20) {
                Button {
                    canvasView.undoManager?.undo()
                    BJHaptic.light()
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Button {
                    canvasView.undoManager?.redo()
                    BJHaptic.light()
                } label: {
                    Image(systemName: "arrow.uturn.forward.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    withAnimation(BJAnimation.quickFade) {
                        drawing = PKDrawing()
                    }
                    BJHaptic.warning()
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red.opacity(0.7))
                }
            }
            .padding(.horizontal, BJDesign.Spacing.lg)
            .padding(.vertical, BJDesign.Spacing.sm)

            // Canvas
            DrawingCanvasView(drawing: $drawing, isEditable: true)
                .background(
                    RoundedRectangle(cornerRadius: BJDesign.Radius.medium)
                        .fill(Color.white)
                        .shadow(
                            color: BJDesign.Shadow.soft.color,
                            radius: BJDesign.Shadow.soft.radius,
                            y: BJDesign.Shadow.soft.y
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: BJDesign.Radius.medium))
                .padding(.horizontal, BJDesign.Spacing.lg)
                .padding(.bottom, BJDesign.Spacing.md)
        }
    }
}

// MARK: - Drawing Thumbnail View (read-only display)

struct DrawingThumbnailView: View {
    let drawingID: UUID
    let height: CGFloat

    @State private var thumbnail: UIImage?

    var body: some View {
        Group {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: BJDesign.Radius.small))
            } else {
                RoundedRectangle(cornerRadius: BJDesign.Radius.small)
                    .fill(Color(.systemGray6))
                    .frame(height: height)
                    .overlay {
                        Image(systemName: "pencil.tip")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .onAppear {
            thumbnail = DrawingStorageManager.shared.loadThumbnail(id: drawingID)
        }
    }
}
