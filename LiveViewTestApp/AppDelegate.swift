//
//  See LICENSE folder for this template’s licensing information.
//
//  Abstract:
//  Implements the application delegate for LiveViewTestApp with appropriate configuration points.
//

import UIKit
import SwiftUI
import PlaygroundSupport
import LiveViewHost
import BookCore

@UIApplicationMain
class AppDelegate: LiveViewHost.AppDelegate {
    override func setUpLiveView() -> PlaygroundLiveViewable {
        // This method should return a fully-configured live view. This method must be implemented.
        //
        // The view or view controller returned from this method will be automatically be shown on screen,
        // as if it were a live view in Swift Playgrounds. You can control how the live view is shown by
        // changing the implementation of the `liveViewConfiguration` property below.
        return getRealWorldView(
            withDistanceMap: true,
            withDistanceMeasurement: true,
            onReceiveCategorizedDistanceUpdate:  { distances in
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
            })
    }

    override var liveViewConfiguration: LiveViewConfiguration {
        // Make this property return the configuration of the live view which you desire to test.
        //
        // Valid values are `.fullScreen`, which simulates when the user has expanded the live
        // view to fill the full screen in Swift Playgrounds, and `.sideBySide`, which simulates when
        // the live view is shown next to or above the source code editor in Swift Playgrounds.
        return .fullScreen
    }
}
