//
//  Helpers.swift
//  BookCore
//
//  Created by Apollo Zhu on 4/17/21.
//

import CoreGraphics
import ARKit
import RealityKit

extension CGRect {
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
}

extension ARMeshClassification {
    init(_ planeAnchorClassification: ARPlaneAnchor.Classification) {
        switch planeAnchorClassification {
        case .none:
            self = .none
        case .wall:
            self = .wall
        case .floor:
            self = .floor
        case .ceiling:
            self = .ceiling
        case .table:
            self = .table
        case .seat:
            self = .seat
        case .window:
            self = .window
        case .door:
            self = .door
        @unknown default:
            self = .none
        }
    }
}

extension ARMeshClassification: CaseIterable {
    public static let allCases: [ARMeshClassification] = [
        .wall,
        .door,
        .window,
        .table,
        .seat,
        .ceiling,
        .floor,
        .none,
    ]
}

// Might be useful if I go back to that approach
//extension ARMeshGeometry {
//    func normalOf(faceWithIndex index: Int) -> (Float, Float, Float) {
//        let vertices = verticesOf(faceWithIndex: index).map { SIMD3<Float>($0.0, $0.1, $0.2) }
//        guard vertices.count == 3 else { return (0, 0, -1) }
//        let (r, b, s) = (vertices[0], vertices[1], vertices[2])
//        let normal = (r - b) * (s - b)
//        return (normal.x, normal.y, normal.z)
//    }
//}
//
//func translationMatrixOf(normal: (Float, Float, Float),
//                         at position: (Float, Float, Float)) -> matrix_float4x4 {
//    let (x, y, z) = normal
//    let sqrted = sqrt(pow(x, 2) + pow(y, 2))
//
//    return simd_matrix(
//        SIMD4<Float>(y / sqrted,     -x / sqrted,       0,          0),
//        SIMD4<Float>(x * z / sqrted, y * z / sqrted,    -sqrted,    0),
//        SIMD4<Float>(x,              y,                 z,          0),
//        SIMD4<Float>(position.0,     position.1,        position.2, 1)
//    )
//}
//
//extension float4x4 {
//    var orientation: simd_quatf {
//        return simd_quaternion(self)
//    }
//}
