//#-hidden-code
//
//  See LICENSE folder for this template’s licensing information.
//
//  Abstract:
//  The Swift file containing the source code edited by the user of this playground book.
//

import BookCore

//#-end-hidden-code

// TODO: write the intro

viewRealWorld(
    withDistanceMap: /*#-editable-code see more than what you see?*/false/*#-end-editable-code*/,
    withDistanceMeasurement: /*#-editable-code how far exactly?*/true/*#-end-editable-code*/,
    onReceiveDistanceUpdate: { distance in
        //#-editable-code what will you do with this new power?
        switch distance {
        case ..<0.5: /* meters */
            say("watch out!")
        case ..<2: /* meters */
            say("\(distance, decimalPlaces: 1) meter")
        default: /* otherwise, >= 2 meters */
            say("\(distance, decimalPlaces: 1) meters")
        }
        //#-end-editable-code
    }
)
