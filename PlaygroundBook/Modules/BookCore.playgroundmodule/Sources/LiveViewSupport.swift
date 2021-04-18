//
//  See LICENSE folder for this template’s licensing information.
//
//  Abstract:
//  Provides supporting functions for setting up a live view.
//

import UIKit
import PlaygroundSupport

public func getRealWorldView(
    withDistanceMap showMesh: Bool = true,
    withDistanceMeasurement showDistance: Bool = true,
    onReceiveDistanceUpdate processDistance: @escaping (Float) -> Void = { _ in }
) -> RealityViewController {
    let viewController = RealityViewController()
    viewController.state = .init(
        showMesh: showMesh,
        showDistance: showDistance,
        didReceiveDistanceFromCenterToWorld: processDistance
    )
    return viewController
}

public func viewRealWorld(
    withDistanceMap showMesh: Bool,
    withDistanceMeasurement showDistance: Bool,
    onReceiveDistanceUpdate processDistance: @escaping (Float) -> Void = { _ in }
) {
    PlaygroundPage.current.setLiveView(getRealWorldView(
        withDistanceMap: showMesh,
        withDistanceMeasurement: showDistance,
        onReceiveDistanceUpdate: processDistance
    ))
}
