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

//#-code-completion(everything, hide)
//#-code-completion(literal, show, boolean)

//#-end-hidden-code

//: - Important: You **MUST** run this Playground with a device that has a LiDAR Scanner, such as a 2020 iPad Pro.

/*:
 # 🎥 Hello World

 If you run the code now, what you'll see is just the normal world captured through the camera lenses. But can our smart devices know a a little more about our surroundings than just a bunch of colored pixels?

 - Experiment: Set `showDistanceMap` to `true`:
 */

let showDistanceMap: Bool = /*#-editable-code see more than what you see?*/false/*#-end-editable-code*/

/*:
 As you can see, there's an overlay on top the real world objects, name it walls, windows, chairs, and etc..

 - Note: The colors used for the overlay corresponds to how far you are to that point. If it's very close, it'll be back. As the point gets further away, the color changes to red, green, blue, and eventually white after 5 meters:
 ![color gradient, colors from 0 meter to 5 meters changes from black to white as described](MapKey.png)

 ## 📐 But how far exactly?

 One thing that I can never gauge is how far am I away from other things, and I feel very nervous when I'm asked to help others park their cars (because I can't tell them what's the distance between the car and the boundaries). But we have a good news: it's possible to let your smart devices tell you how far is the thing shown in the center of your screen away from you.

 - Experiment: Set `showDistanceMeasurement` to `true`:
 */

let showDistanceMeasurement: Bool = /*#-editable-code how far exactly?*/false/*#-end-editable-code*/

/*:
 As you see, we gained this new power of distance measuring.
 */
viewRealWorld(
    withDistanceMap: showDistanceMap,
    withDistanceMeasurement: showDistanceMeasurement
    //#-hidden-code
    // some hack for starting background music ;)
    , markerForNearestPoint: {
        let marker = AnchorEntity()
        marker.name = ._backgroundMusicAnchorName
        if showDistanceMeasurement {
            let audio = try! AudioFileResource
                .load(named: "Afloat Pad.caf",
                      inputMode: .nonSpatial,
                      shouldLoop: true)
            marker.playAudio(audio)
        }
        return marker
    }
    //#-end-hidden-code
)
//: - Experiment: This will be challenging, but with these new powers, try dimming the light and use the distance map/measurement to navigate around. See how they can help you navigate the space.
