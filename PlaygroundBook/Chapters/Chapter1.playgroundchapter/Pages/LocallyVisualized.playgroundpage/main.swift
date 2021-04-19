//#-hidden-code
//
//  See LICENSE folder for this template’s licensing information.
//
//  Abstract:
//  The Swift file containing the source code edited by the user of this playground book.
//

import BookCore
import ARKit
import RealityKit

//#-code-completion(module, hide, BookCore)

//#-end-hidden-code

/*:
 # 😎 Hear See

 Well, certainly having someone speak out when we are close to some obstacles are helpful, but what if, we can know where exactly we could potential hit, without necessarily seeing it?

 Since we already have the depth data of the surroundings, in addition to our existing code in `handleDistances`, we could:

 1. locate the point that's closet us, and keep track of it;
 2. play, with spatial audio, a sound track from that point

 With these steps, it's possible to hear the nearest obstacle, and thus navigate the space without bumping into anything.
 */

viewRealWorld(
    withDistanceMap: /*#-editable-code see more than what you see?*/false/*#-end-editable-code*/,
    withDistanceMeasurement: /*#-editable-code how far exactly?*/true/*#-end-editable-code*/,
    onReceiveCategorizedDistanceUpdate: /*#-editable-code how do you want to handle different kinds of distances?*/handleDistances/*#-end-editable-code*/,
//: - Important: Let's configure a pin shaped marker, and play a clock-ticking sound from the marker pin.
    markerForNearestPoint: {
        let marker = AnchorEntity()
        //#-editable-code how do we keep users more clearly guided?
        let model = try! Experience.loadPin().pin!
        marker.addChild(model)
        let audio = try! AudioFileResource
            .load(named: "Clock Cartoon.caf",
                  inputMode: .spatial,
                  shouldLoop: true)
        marker.playAudio(audio)
        //#-end-editable-code
        return marker
    }
)

/*:
 - Experiment: That was fun, but you could try additional customizations for the nearest location marker.

 You could use [Reality Composer](https://developer.apple.com/augmented-reality/tools/) to design a different marker shape, or just generate a simple spherical one using the code below (to replace `model`):

 ```swift
 let mesh = MeshResource.generateSphere(radius: 0.05)
 let material = SimpleMaterial(color: #colorLiteral(red: 0.4, green: 0.8, blue: 1, alpha: 1), isMetallic: false)
 let model = ModelEntity(mesh: mesh, materials: [material])
 ```
 */
