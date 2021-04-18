//
//  Extensions.swift
//  BookCore
//
//  Created by Apollo Zhu on 4/17/21.
//

import SwiftUI
import UIKit
import ARKit
import RealityKit

extension RealityViewController {
    internal func generateText(_ text: String, color: () -> UIColor) -> ModelEntity {
        if let model = _cache[text] {
            model.transform = .identity
            return model.clone(recursive: true)
        }

        let lineHeight: CGFloat = 0.05
        let font = MeshResource.Font.systemFont(ofSize: lineHeight)
        let textMesh = MeshResource.generateText(text, extrusionDepth: Float(lineHeight * 0.1), font: font)
        let textMaterial = UnlitMaterial(color: color())
        let model = ModelEntity(mesh: textMesh, materials: [textMaterial])
        // Move text geometry to the left so that its local origin is in the center
        model.position.x -= model.visualBounds(relativeTo: nil).extents.x / 2
        _cache[text] = model
        return model
    }

    public func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap { $0 }.joined(separator: "\n")
        DispatchQueue.main.async { [weak self] in
            let alertController = UIAlertController(title: "The AR session failed.",
                                                    message: errorMessage,
                                                    preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session",
                                              style: .default) {
                [weak self] _ in
                alertController.dismiss(animated: true, completion: nil)
                self?.resetARSession()
            }
            alertController.addAction(restartAction)
            self?.present(alertController, animated: true, completion: nil)
        }
    }

    func setupCoachingOverlay() {
        // Set up coaching view
        coachingOverlay.session = arView.session
        coachingOverlay.delegate = self

        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(coachingOverlay)

        NSLayoutConstraint.activate([
            coachingOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            coachingOverlay.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            coachingOverlay.widthAnchor.constraint(equalTo: view.widthAnchor),
            coachingOverlay.heightAnchor.constraint(equalTo: view.heightAnchor)
        ])
    }
}

extension simd_float4x4 {
    var position: SIMD3<Float> {
        return SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}

extension ARMeshGeometry {
    func vertex(at index: UInt32) -> (Float, Float, Float) {
        assert(vertices.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per vertex.")
        let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + (vertices.stride * Int(index)))
        let vertex = vertexPointer.assumingMemoryBound(to: (Float, Float, Float).self).pointee
        return vertex
    }

    /// To get the mesh's classification, the sample app parses the classification's raw data and instantiates an
    /// `ARMeshClassification` object. For efficiency, ARKit stores classifications in a Metal buffer in `ARMeshGeometry`.
    func classificationOf(faceWithIndex index: Int) -> ARMeshClassification {
        guard let classification = classification else { return .none }
        assert(classification.format == MTLVertexFormat.uchar, "Expected one unsigned char (one byte) per classification")
        let classificationPointer = classification.buffer.contents().advanced(by: classification.offset + (classification.stride * index))
        let classificationValue = Int(classificationPointer.assumingMemoryBound(to: CUnsignedChar.self).pointee)
        return ARMeshClassification(rawValue: classificationValue) ?? .none
    }

    func vertexIndicesOf(faceWithIndex faceIndex: Int) -> [UInt32] {
        assert(faces.bytesPerIndex == MemoryLayout<UInt32>.size, "Expected one UInt32 (four bytes) per vertex index")
        let vertexCountPerFace = faces.indexCountPerPrimitive
        let vertexIndicesPointer = faces.buffer.contents()
        var vertexIndices = [UInt32]()
        vertexIndices.reserveCapacity(vertexCountPerFace)
        for vertexOffset in 0..<vertexCountPerFace {
            let vertexIndexPointer = vertexIndicesPointer.advanced(by: (faceIndex * vertexCountPerFace + vertexOffset) * MemoryLayout<UInt32>.size)
            vertexIndices.append(vertexIndexPointer.assumingMemoryBound(to: UInt32.self).pointee)
        }
        return vertexIndices
    }

    func verticesOf(faceWithIndex index: Int) -> [(Float, Float, Float)] {
        let vertexIndices = vertexIndicesOf(faceWithIndex: index)
        let vertices = vertexIndices.map { vertex(at: $0) }
        return vertices
    }

    func centerOf(faceWithIndex index: Int) -> (Float, Float, Float) {
        let vertices = verticesOf(faceWithIndex: index)
        let sum = vertices.reduce((0, 0, 0)) { ($0.0 + $1.0, $0.1 + $1.1, $0.2 + $1.2) }
        let geometricCenter = (sum.0 / 3, sum.1 / 3, sum.2 / 3)
        return geometricCenter
    }
}

extension ARMeshClassification {
    var description: String {
        switch self {
        case .ceiling: return "Ceiling"
        case .door: return "Door"
        case .floor: return "Floor"
        case .seat: return "Seat"
        case .table: return "Table"
        case .wall: return "Wall"
        case .window: return "Window"
        case .none: return "None"
        @unknown default: return "Unknown"
        }
    }
}
