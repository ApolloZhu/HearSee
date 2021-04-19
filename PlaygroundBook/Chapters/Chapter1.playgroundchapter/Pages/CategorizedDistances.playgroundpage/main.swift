//#-hidden-code
//
//  See LICENSE folder for this template’s licensing information.
//
//  Abstract:
//  The Swift file containing the source code edited by the user of this playground book.
//

import UserModule
import BookCore

//#-code-completion(everything, hide)
//#-code-completion(literal, show, boolean)

//#-end-hidden-code

/*:
 # 🗂 Special Treatments

 In addition to the point in the middle of the screen, it would be also useful to know other edges of objects in the real world that we can interact with. Let's focus on the points in space that are closest to us, since it's more likely for us to walk into them (because of reduced vision, or just because we are not paying attention).

 However, we might not be as concerned depending on which type of things we are going to collide with. The different possible types of surfaces are:

 - ceiling, especially they are low;
 - door
 - floor
 - seat
 - table
 - wall; or
 - something else.

 So for this page, we'll write code to handle the nearest points to us, after checking all the surfaces in the surrounding environment and classifying what they are:
 */
viewRealWorld(
    withDistanceMap: /*#-editable-code see more than what you see?*/false/*#-end-editable-code*/,
    withDistanceMeasurement: /*#-editable-code how far exactly?*/true/*#-end-editable-code*/,
//: - Experiment: Change how you are handling the different kinds of closet distances in `SharedCode.swift`.
    onReceiveCategorizedDistanceUpdate: handleDistances
)
//: - Note: To help you check what are the minimum distances to different surfaces, there's a little panel on the lower right corner of the screen that are constantly updated with the most recent data.
