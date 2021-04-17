//
//  See LICENSE folder for this template’s licensing information.
//
//  Abstract:
//  Provides supporting functions for setting up a live view.
//

import UIKit
import PlaygroundSupport

let viewController = RealityViewController()

public func viewRealWorld(withDistanceMap showMesh: Bool) {
    viewController.showMesh = showMesh
    PlaygroundPage.current.setLiveView(viewController)
}
