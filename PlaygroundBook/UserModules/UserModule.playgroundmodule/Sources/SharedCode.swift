import ARKit
import BookAPI
import BookCore
import RealityKit

// REMINDER: Remember to check out "Main" portion of this page to see more!

/// Processes information about the closest points to us.
///
/// - Parameter distances: a dictionary of nearest distances, categorized by type classification.
public func handleDistances(_ distances: [ARMeshClassification: Float]) {
    // let's process the distances based on how close they are.
    for (category, distance) in distances.sorted(by: { $0.value < $1.value }) {
        switch category {
        // for walls, only warns if is too close (25 centimeters).
        case .wall:
            if distance < 0.3 /* meter */ {
                return say("\(distance, decimalPlaces: 1) meter from wall")
            }
        // for example, someone into aviation could use some jargons:
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
        // you can set different range for different types of surfaces
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
        // for handling any other kind of obstacles:
        case .none:
            if distance < 0.4 /* meter */ {
                return say("\(distance, decimalPlaces: 1) meter")
            }
        // maybe in the future there'll be some more kinds to handle, but let's just ignore it for now
        @unknown default:
            break
        }
    }
}
