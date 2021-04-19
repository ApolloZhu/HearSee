//
//  See LICENSE folder for this template’s licensing information.
//
//  Abstract:
//  Provides supporting functions for setting up a live view.
//

import ARKit
import UIKit
import SwiftUI
import RealityKit
import PlaygroundSupport

public func _getRealWorldView(
    withDistanceMap showMesh: Bool = true,
    withDistanceMeasurement showDistance: Bool = true,
    onReceiveDistanceUpdate processDistance: ((Float) -> Void)? = nil,
    onReceiveCategorizedDistanceUpdate processCategorizedDistances: (([ARMeshClassification: Float]) -> Void)? = nil,
    markerForNearestPoint: @escaping () -> AnchorEntity = { AnchorEntity() }
) -> RealityViewController {
    let viewController = RealityViewController()
    viewController.state = .init(
        showMesh: showMesh,
        showDistance: showDistance,
        didReceiveDistanceFromCameraToPointInWorldAtCenterOfView: processDistance,
        didReceiveMinDistanceFromCamera: processCategorizedDistances,
        anchorEntityForMinDistanceFromCamera: markerForNearestPoint
    )
    return viewController
}

public func viewRealWorld(
    withDistanceMap showMesh: Bool,
    withDistanceMeasurement showDistance: Bool,
    onReceiveDistanceUpdate processDistance: ((Float) -> Void)? = nil,
    onReceiveCategorizedDistanceUpdate processCategorizedDistances: (([ARMeshClassification: Float]) -> Void)? = nil,
    markerForNearestPoint: @escaping () -> AnchorEntity = { AnchorEntity() }
) {
    guard ARWorldTrackingConfiguration.isSupported else {
        PlaygroundPage.current.setLiveView(Text(
            "ARKit is not available on this device. For details, see https://developer.apple.com/documentation/arkit"
        ))
        return
    }
    guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) else {
        PlaygroundPage.current.setLiveView(Text(
            "Scene reconstruction requires a device with a LiDAR Scanner, such as the 4th-Gen iPad Pro."
        ))
        return
    }
    PlaygroundPage.current.setLiveView(_getRealWorldView(
        withDistanceMap: showMesh,
        withDistanceMeasurement: showDistance,
        onReceiveDistanceUpdate: processDistance,
        onReceiveCategorizedDistanceUpdate: processCategorizedDistances,
        markerForNearestPoint: markerForNearestPoint
    ))
}
