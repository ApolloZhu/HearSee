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
