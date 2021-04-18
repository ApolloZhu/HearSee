//
//  RealityViewController.swift
//  BookCore
//
//  Created by Apollo Zhu on 4/16/21.
//

import UIKit
import ARKit
import RealityKit

public class RealityViewController: UIViewController, ARSessionDelegate, ARCoachingOverlayViewDelegate {
    internal struct State {
        var showMesh: Bool = true
        var showDistance: Bool = true
        var didReceiveDistanceFromCenterToWorld: (Float) -> Void = { _ in }
        var didReceiveMinDistanceToCamera: (Float) -> Void = { _ in }
    }
    internal var state: State = State() {
        didSet {
            updateForConfigs()
        }
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupCoachingOverlay()
        arView.session.delegate = self
        arView.environment.sceneUnderstanding.options = [.occlusion, .physics,]
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]
        arView.automaticallyConfigureSession = false
        updateForConfigs()
    }

    private lazy var minDistanceAnchor: AnchorEntity = {
        let entity = AnchorEntity(world: [0, 0, 0])
        let pin = try! Experience.loadPin().pin!
        entity.addChild(pin)
        arView.scene.addAnchor(entity)
        return entity
    }()
    private var previousCenterAnchor: AnchorEntity?
    private var isUpdating = false
    private func updateRaycast() {
        if isUpdating || !state.showDistance { return }
        isUpdating = true
        guard let result = arView.raycast(from: arView.bounds.center,
                                          allowing: .estimatedPlane,
                                          alignment: .any).first
        else { isUpdating = false; return }
        let cameraTransform = arView.cameraTransform
        let resultWorldPosition = result.worldTransform.position
        let raycastDistance = distance(resultWorldPosition, cameraTransform.translation)
        let rayDirection = normalize(resultWorldPosition - cameraTransform.translation)
        let textPositionInWorldCoordinates = resultWorldPosition - (rayDirection * 0.1)

        func updateTextWithOrientation(_ orientation: Transform) {
            #warning("TODO: remove X before submission")
            let textEntity = self.generateText(
                String(format: "%.1fm\(orientation == cameraTransform ? "X" : "")", raycastDistance),
                color: {
                    switch raycastDistance {
                    case ...1.4: return UIColor.systemRed
                    case ...1.875: return UIColor.systemOrange
                    case ...2.75: return UIColor.systemGreen
                    case ...3.125: return UIColor.systemTeal
                    case ...3.75: return UIColor.systemBlue
                    default: return UIColor.systemIndigo // ~5 meters
                    }
                }
            )
            // 6. Scale the text depending on the distance,
            // such that it always appears with the same size on screen.
            textEntity.scale = .one * raycastDistance

            // 7. Place the text, facing the transform.
            var finalTransform = orientation
            finalTransform.translation = textPositionInWorldCoordinates
            let textAnchor = AnchorEntity(world: finalTransform.matrix)
            textAnchor.addChild(textEntity, preservingWorldTransform: true)
            previousCenterAnchor?.removeFromParent()
            arView.scene.addAnchor(textAnchor)
            previousCenterAnchor = textAnchor
            state.didReceiveDistanceFromCenterToWorld(raycastDistance)
            isUpdating = false
        }

        guard state.showMesh else {
            updateTextWithOrientation(cameraTransform)
            return
        }

        processAllAnchors(centerWorldPosition: resultWorldPosition) { result in
            DispatchQueue.main.async {
                if let result = result {
                    //                    self.previousMinAnchor?.removeFromParent()
                    //                    let anchor = AnchorEntity(world: result.minDistanceToCameraAnchor.transform.position)
                    //                    let pin = try! Experience.loadPin().pin!
                    //                    anchor.addChild(pin)
                    //                    self.previousMinAnchor = anchor
                    if let center = result.center {
                        let transform = Transform(matrix: center.worldTransform)
                        #warning("TODO: make sure text have same orientation as surface")
                        // transform.rotation = simd_slerp(transform.rotation, cameraTransform.rotation, 0.5)
                        updateTextWithOrientation(transform)
                    } else {
                        updateTextWithOrientation(cameraTransform)
                    }
                    let minClassification = result.minDistanceToCamera.classification
                    let type: String = minClassification == .none
                        ? ""
                        : minClassification.description
                    let distance = result.minDistanceToCamera.inMeters
                    if distance < 0.5 {
                        speak("\(type) \(distance, decimalPlaces: 1) meter")
                    }
                    self.minDistanceAnchor.transform = Transform(matrix: result.minDistanceToCamera.worldTransform)
                } else {
                    updateTextWithOrientation(cameraTransform)
                }
            }
        }
    }

    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        updateRaycast()
    }


    private struct AnchorSummary {
        let center: (worldTransform: simd_float4x4, classification: ARMeshClassification)?
        let minDistanceToCamera: (inMeters: Float, worldTransform: simd_float4x4, classification: ARMeshClassification)
    }
    private func processAllAnchors(
        centerWorldPosition location: SIMD3<Float>,
        completionBlock: @escaping (AnchorSummary?) -> Void
    ) {
        guard let anchors = arView.session.currentFrame?.anchors else {
            return completionBlock(nil)
        }
        let cameraTransform = arView.cameraTransform

        // Perform the search asynchronously in order not to stall rendering.
        _myWorkQueue.async {
            let centerPointCutoffDistance: Float = 4.0

            var minDistanceToPOI: Float? = nil
            var poiWorldTransform: simd_float4x4? = nil
            var poiClassification: ARMeshClassification = .none

            var minDistanceToCamera: Float? = nil
            var minDistanceToCameraWorldTransform: simd_float4x4? = nil
            var minDistanceToCameraClassification: ARMeshClassification = .none


            // Use O(n) instead O(n log n) sorting so processing anchors are faster
            for case let anchor as ARMeshAnchor in anchors {
                let distanceToPOI = distance(anchor.transform.position, location)
                guard distanceToPOI < centerPointCutoffDistance else { continue }

                for index in 0..<anchor.geometry.faces.count {
                    // Get the center of the face so that we can compare it to the given location.
                    let geometricCenterOfFace = anchor.geometry.centerOf(faceWithIndex: index)

                    // Convert the face's center to world coordinates.
                    var centerLocalTransform = matrix_identity_float4x4
                    centerLocalTransform.columns.3 = SIMD4<Float>(
                        geometricCenterOfFace.0,
                        geometricCenterOfFace.1,
                        geometricCenterOfFace.2,
                        1
                    )
                    let centerWorldTransform = anchor.transform * centerLocalTransform
                    let centerWorldPosition = centerWorldTransform.position

                    // We're interested in a classification that is sufficiently close to the given location––within 5 cm.
                    let distanceToFace = distance(centerWorldPosition, location)
                    let classification = anchor.geometry.classificationOf(faceWithIndex: index)
                    if distanceToFace <= 0.05 {
                        if minDistanceToPOI == nil || distanceToPOI < minDistanceToPOI! {
                            minDistanceToPOI = distanceToPOI
                            // Get the semantic classification of the face and finish the search.
                            poiClassification = classification
                            poiWorldTransform = centerWorldTransform
                        }
                    }

                    // closest point shall not be about floors
                    guard classification != .floor else { continue }
                    let pointDistanceToCamera = distance(centerWorldPosition, cameraTransform.matrix.position)
                    if minDistanceToCamera == nil || pointDistanceToCamera < minDistanceToCamera! {
                        minDistanceToCameraWorldTransform = centerWorldTransform
                        minDistanceToCamera = pointDistanceToCamera
                        minDistanceToCameraClassification = classification
                    }
                }
            }
            guard let anchor = minDistanceToCameraWorldTransform,
                  let distance = minDistanceToCamera
            else {
                return completionBlock(nil)
            }

            completionBlock(.init(
                center: poiWorldTransform.map { (worldTransform: $0, classification: poiClassification) },
                minDistanceToCamera: (inMeters: distance, worldTransform: anchor, classification: minDistanceToCameraClassification)
            ))
        }
    }


    private func updateForConfigs() {
        if !state.showDistance {
            previousCenterAnchor?.removeFromParent()
        }

        let configuration = ARWorldTrackingConfiguration()
        if state.showMesh {
            configuration.sceneReconstruction = .meshWithClassification
            arView.debugOptions.insert(.showSceneUnderstanding)
        } else {
            arView.debugOptions.remove(.showSceneUnderstanding)
        }
        configuration.environmentTexturing = .automatic
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration)
    }

    // MARK: - Coaching
    private var previousState: State?
    public func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
        previousState = state
    }

    public func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        state = previousState ?? State()
    }

    public func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
        resetARSession()
    }

    func resetARSession() {
        if let configuration = arView.session.configuration {
            arView.session.run(configuration, options: .resetSceneReconstruction)
        }
    }

    // MARK: - Helpers
    internal var _cache: [String: ModelEntity] = [:]
    internal let _myWorkQueue = DispatchQueue(label: "RealityViewController")
    internal let coachingOverlay = ARCoachingOverlayView()

    var arView: ARView {
        return view as! ARView
    }

    public override func loadView() {
        self.view = ARView(frame: .zero, cameraMode: .ar,
                           automaticallyConfigureSession: false)
    }

    public override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    public override var prefersStatusBarHidden: Bool {
        return true
    }
}
