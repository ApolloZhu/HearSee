//
//  See LICENSE folder for this template’s licensing information.
//
//  Abstract:
//  Provides supporting functions for setting up a live view.
//

import UIKit
import PlaygroundSupport

public func getRealWorldView(
    withDistanceMeasurement showDistance: Bool = true,
    withDistanceMap showMesh: Bool = true
) -> RealityViewController {
    let viewController = RealityViewController()
    viewController.state = .init(
        showMesh: showMesh,
        showDistance: showDistance
    )
    return viewController
}

public func viewRealWorld(
    withDistanceMeasurement showDistance: Bool,
    withDistanceMap showMesh: Bool
) {

    PlaygroundPage.current.setLiveView(getRealWorldView(
        withDistanceMeasurement: showDistance,
        withDistanceMap: showMesh
    ))
}
