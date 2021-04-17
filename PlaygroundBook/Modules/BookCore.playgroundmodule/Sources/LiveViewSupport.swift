//
//  See LICENSE folder for this template’s licensing information.
//
//  Abstract:
//  Provides supporting functions for setting up a live view.
//

import UIKit
import PlaygroundSupport

public func viewRealWorld(withDistanceMap showMesh: Bool) {
    let viewController = RealityViewController()
    viewController.showMesh = showMesh
    PlaygroundPage.current.setLiveView(viewController)
}
