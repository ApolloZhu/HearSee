//
//  See LICENSE folder for this template’s licensing information.
//
//  Abstract:
//  Provides supporting functions for setting up a live view.
//

import UIKit
import ARKit
import RealityKit
import PlaygroundSupport

public func getRealWorldView(
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
    PlaygroundPage.current.setLiveView(getRealWorldView(
        withDistanceMap: showMesh,
        withDistanceMeasurement: showDistance,
        onReceiveDistanceUpdate: processDistance,
        onReceiveCategorizedDistanceUpdate: processCategorizedDistances,
        markerForNearestPoint: markerForNearestPoint
    ))
}
