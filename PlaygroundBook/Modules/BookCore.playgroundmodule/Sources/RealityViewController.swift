//
//  RealityViewController.swift
//  BookCore
//
//  Created by Apollo Zhu on 4/16/21.
//

import UIKit
import SwiftUI
import ARKit
import RealityKit

public class RealityViewController: UIViewController,
                                    ARSessionDelegate, ARCoachingOverlayViewDelegate,
                                    ObservableObject {
    internal struct State {
        var showMesh: Bool = false
        var showDistance: Bool = false
        var didReceiveDistanceFromCameraToPointInWorldAtCenterOfView: ((Float) -> Void)? = nil
        var didReceiveMinDistanceFromCamera: (([ARMeshClassification: Float]) -> Void)? = nil
        var anchorEntityForMinDistanceFromCamera: () -> AnchorEntity = { AnchorEntity() }
        var colorForDistance: (Float) -> UIColor = { distance in
            switch distance {
            case ...1.4: return UIColor.systemRed
            case ...1.875: return UIColor.systemOrange
            case ...2.75: return UIColor.systemGreen
            case ...3.125: return UIColor.systemTeal
            case ...3.75: return UIColor.systemBlue
            default: return UIColor.systemIndigo // ~5 meters
            }
        }
    }
    @Published
    internal var state: State = State() {
        didSet {
            DispatchQueue.main.async(execute: updateForConfigs)
        }
    }
    @Published
    public var _anchorSummary: AnchorSummary? = nil

    private lazy var minDistanceAnchor: AnchorEntity = AnchorEntity()
    private var previousTextEntity: ModelEntity? = nil
    private lazy var centerAnchor: AnchorEntity = {
        let textAnchor = AnchorEntity()
        //        textAnchor.components[]
        arView.scene.addAnchor(textAnchor)
        return textAnchor
    }()
    private var isUpdating = false
    private func updateRaycast() {
        guard let raycastResult = arView.raycast(from: arView.bounds.center,
                                                 allowing: .estimatedPlane,
                                                 alignment: .any).first
        else { return }

        let cameraTransform = arView.cameraTransform
        let resultWorldPosition = raycastResult.worldTransform.position
        let raycastDistance = distance(resultWorldPosition, cameraTransform.translation)
        let rayDirection = normalize(resultWorldPosition - cameraTransform.translation)
        let textPositionInWorldCoordinates = resultWorldPosition - (rayDirection * 0.1)
        let raycastPlaneClassification: ARMeshClassification?
            = raycastResult.anchor
            .flatMap { $0 as? ARPlaneAnchor }
            .map { ARMeshClassification($0.classification) }

        func updateTextWithOrientation() {
            defer {
                // just update the center point faster
                var distances = _anchorSummary?.minDistanceToCamera ?? [:]
                distances[raycastPlaneClassification ?? .none] = (inMeters: raycastDistance,
                                                                  worldTransform: raycastResult.worldTransform)
                updateForNearestDistances(distances)
                // always inform the delegates
                state.didReceiveDistanceFromCameraToPointInWorldAtCenterOfView?(raycastDistance)
                state.didReceiveMinDistanceFromCamera?(distances.mapValues { $0.inMeters })
            }

            if !state.showDistance { return }
            let textEntity = self.generateText(
                String(format: "%.1fm", raycastDistance),
                color: state.colorForDistance(raycastDistance)
            )
            // 6. Scale the text depending on the distance,
            // such that it always appears with the same size on screen.
            textEntity.scale = .one * raycastDistance

            // 7. Place the text at the raycasted location, somewhat facing the camera
            var transform = Transform(matrix: raycastResult.worldTransform)
            transform.translation = textPositionInWorldCoordinates
            transform.rotation = simd_slerp(transform.rotation, cameraTransform.rotation, 0.5)

            previousTextEntity?.removeFromParent()
            previousTextEntity = textEntity
            centerAnchor.addChild(textEntity)
            centerAnchor.move(to: transform, relativeTo: nil, duration: 0.1)
        }

        if !isUpdating {
            isUpdating = true
            processAllAnchors(centerWorldPosition: resultWorldPosition) { [weak self] result in
                let raycastClassification = raycastPlaneClassification
                    ?? result?.center?.classification
                    ?? .none
                var distances = [raycastClassification: raycastDistance]
                let newSummary: AnchorSummary
                if let result = result {
                    distances.merge(result.minDistanceToCamera.mapValues { $0.inMeters },
                                    uniquingKeysWith: min)
                    newSummary = result
                } else {
                    newSummary = AnchorSummary(
                        center: nil,
                        minDistanceToCamera: [
                            raycastClassification : (inMeters: raycastDistance,
                                                     worldTransform: raycastResult.worldTransform)
                        ]
                    )
                }

                DispatchQueue.main.async {
                    self?._anchorSummary = newSummary
                    self?.updateForNearestDistances(newSummary.minDistanceToCamera)
                    self?.isUpdating = false
                    self?.state.didReceiveMinDistanceFromCamera?(distances)
                }
            }
        }
        updateTextWithOrientation()
    }

    private func updateForNearestDistances(_ distances: CategorizedDistances) {
        guard !distances.isEmpty else { return }
        // we know for sure there's at least an element
        let closest = distances
            .sorted { $0.value.inMeters < $1.value.inMeters }
            .first!
        minDistanceAnchor.move(to: closest.value.worldTransform, relativeTo: nil,
                               duration: 0.2, timingFunction: .easeInOut)
    }

    typealias CategorizedDistances = [ARMeshClassification: (inMeters: Float, worldTransform: simd_float4x4)]
    public struct AnchorSummary {
        let center: (worldTransform: simd_float4x4, classification: ARMeshClassification)?
        let minDistanceToCamera: CategorizedDistances
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

            var minDistanceToCamera: CategorizedDistances = [:]

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
                    let minDistanceToCameraForCurrentClassification = minDistanceToCamera[classification]
                    let pointDistanceToCamera = distance(centerWorldPosition, cameraTransform.matrix.position)

                    if minDistanceToCameraForCurrentClassification == nil
                        || pointDistanceToCamera < minDistanceToCameraForCurrentClassification!.inMeters {
                        minDistanceToCamera[classification] = (pointDistanceToCamera, centerWorldTransform)
                    }
                }
            }
            guard !minDistanceToCamera.isEmpty else {
                return completionBlock(nil)
            }

            completionBlock(.init(
                center: poiWorldTransform.map { (worldTransform: $0, classification: poiClassification) },
                minDistanceToCamera: minDistanceToCamera
            ))
        }
    }

    // MARK: - Life Cycle
    public override func viewDidLoad() {
        super.viewDidLoad()
        addHUD()
        setupCoachingOverlay()
        updateForConfigs()

        arView.session.delegate = self
        arView.environment.sceneUnderstanding.options = [.occlusion, .receivesLighting]
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]
        arView.automaticallyConfigureSession = false

        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .meshWithClassification
        configuration.environmentTexturing = .automatic
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration)
    }

    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        updateRaycast()
    }

    private func updateForConfigs() {
        if !state.showDistance {
            previousTextEntity?.removeFromParent()
        }
        let noHandleMinDistances = (state.didReceiveMinDistanceFromCamera == nil)
        hud.view.isHidden = noHandleMinDistances

        minDistanceAnchor.stopAllAudio()
        minDistanceAnchor.stopAllAnimations(recursive: true)
        minDistanceAnchor.removeFromParent()

        // workaround for background music
        let newAnchor = state.anchorEntityForMinDistanceFromCamera()
        if !noHandleMinDistances || newAnchor.name == ._backgroundMusicAnchorName {
            minDistanceAnchor = newAnchor
            arView.scene.addAnchor(minDistanceAnchor)
        } else {
            newAnchor.stopAllAudio()
        }

        if state.showMesh {
            arView.debugOptions.insert(.showSceneUnderstanding)
        } else {
            arView.debugOptions.remove(.showSceneUnderstanding)
        }
    }

    // MARK: - Coaching
    private var previousState: State?
    public func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
        previousState = state
        state = State()
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

    private lazy var hud = UIHostingController(rootView: HUD(dataSource: self))
    func addHUD() {
        addChild(hud)
        arView.addSubview(hud.view)
        hud.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hud.view.centerXAnchor.constraint(equalTo: arView.centerXAnchor),
            hud.view.centerYAnchor.constraint(equalTo: arView.centerYAnchor),
            hud.view.widthAnchor.constraint(equalTo: arView.widthAnchor),
            hud.view.heightAnchor.constraint(equalTo: arView.heightAnchor)
        ])
        hud.view.backgroundColor = .clear
        hud.didMove(toParent: self)
    }

    public override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    public override var prefersStatusBarHidden: Bool {
        return true
    }
}
