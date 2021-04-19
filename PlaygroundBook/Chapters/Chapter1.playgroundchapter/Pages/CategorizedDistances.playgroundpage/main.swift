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
    onReceiveCategorizedDistanceUpdate: { distances in
        //#-editable-code how do you want to handle different kinds of distances?
        for (category, distance) in distances.sorted(by: { $0.value < $1.value }) {
            switch category {
            // for walls, only warns if is too close (25 centimeters).
            case .wall:
                if distance < 0.3 /* meter */ {
                    return say("\(distance, decimalPlaces: 1) meter from wall")
                }
            // for example, someone into aviation could use some jargons.
            case .floor:
                if distance < 0.4 /* meter */ {
                    return say("terrain, terrain; pull up, pull up")
                } else if distance < 0.7 /* meter */ {
                    return say("caution: terrain; caution: terrain;")
                }
            case .ceiling:
                if distance < 0.25 /* meter */ {
                    return say("cruising altitude")
                }
            case .table:
                if distance < 0.4 /* meter */ {
                    return say("\(distance, decimalPlaces: 1) meter from table")
                }
            case .seat:
                if distance < 0.4 /* meter */ {
                    return say("\(distance, decimalPlaces: 1) meter from seats")
                }
            case .window:
                if distance < 0.25 /* meter */ {
                    return say("\(distance, decimalPlaces: 1) meter from window")
                }
            case .door:
                if distance < 0.3 /* meter */ {
                    return say("\(distance, decimalPlaces: 1) meter from door")
                }
            case .none:
                if distance < 0.4 /* meter */ {
                    return say("\(distance, decimalPlaces: 1) meter")
                }
            @unknown default:
                break  // otherwise, we don't know what's going on
            }
        }
        //#-end-editable-code
    }
)
