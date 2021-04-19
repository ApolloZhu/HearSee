//#-hidden-code
//
//  See LICENSE folder for this template’s licensing information.
//
//  Abstract:
//  The Swift file containing the source code edited by the user of this playground book.
//

import BookCore

//#-code-completion(module, hide, BookCore)
//#-code-completion(module, hide, UserModule)

//#-end-hidden-code

/*:
 # 📢 Watch Out!

 What can we do if we know how close we are to something in front of us? You named it! Let's first try announcing how close we are; And if it's too close, shouts out a warning:
 */
viewRealWorld(
    withDistanceMap: /*#-editable-code see more than what you see?*/false/*#-end-editable-code*/,
    withDistanceMeasurement: /*#-editable-code how far exactly?*/true/*#-end-editable-code*/,
//: - Note: The `say` function speaks out a line of text for you. You can configure it's voice with the "Change Voice" button on the top right corner of the screen.
    onReceiveDistanceUpdate: { distance in
        //#-editable-code what will you do with this new power?
        // check the distance to the thing in front of us
        switch distance {

        /* if it's within */
        case ..<0.5: /* meters, then */
            say("watch out!")

        /* else, if it's within */
        case ..<2: /* meters (so 0.5 ... 1.9), then */
            say("\(distance, decimalPlaces: 1) meter")

        /* otherwise, let's use proper plural form for */
        default: /* >= 2 meters */
            say("\(distance, decimalPlaces: 1) meters")
        }
        //#-end-editable-code
    }
)
//: - Experiment: Change what the Playground says out load, when it does them, or make it do nothing if the distance is too far to concern us.
