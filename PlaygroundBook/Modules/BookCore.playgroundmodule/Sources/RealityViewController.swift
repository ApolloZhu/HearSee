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
    public var showMesh: Bool = false {
        didSet {
            updateForConfigs()
        }
    }

    private var previousCenterAnchor: AnchorEntity?

    public override func viewDidLoad() {
        super.viewDidLoad()
        updateForConfigs()
        setupCoachingOverlay()

        arView.session.delegate = self
        arView.environment.sceneUnderstanding.options = [.occlusion, .physics,]
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]
        arView.automaticallyConfigureSession = false
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .meshWithClassification
        configuration.environmentTexturing = .automatic
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration)
    }

    var cache: [String: ModelEntity] = [:]

    func generateText(_ text: String, color: UIColor) -> ModelEntity {
        if let model = cache[text] {
            model.transform = .identity
            return model.clone(recursive: true)
        }

        let lineHeight: CGFloat = 0.05
        let font = MeshResource.Font.systemFont(ofSize: lineHeight)
        let textMesh = MeshResource.generateText(text, extrusionDepth: Float(lineHeight * 0.1), font: font)
        let textMaterial = UnlitMaterial(color: color)
        let model = ModelEntity(mesh: textMesh, materials: [textMaterial])
        // Move text geometry to the left so that its local origin is in the center
        model.position.x -= model.visualBounds(relativeTo: nil).extents.x / 2
        cache[text] = model
        return model
    }

    private var isUpdating = false
    private func updateRaycast() {
        if isUpdating { return }
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
            let textEntity = self.generateText(String(format: "%.1fm", raycastDistance), color: .systemPink)
            // 6. Scale the text depending on the distance,
            // such that it always appears with the same size on screen.
            textEntity.scale = .one * raycastDistance

            // 7. Place the text, facing the camera.

            var finalTransform = orientation
            finalTransform.translation = textPositionInWorldCoordinates
            let textAnchor = AnchorEntity(world: finalTransform.matrix)
            textAnchor.addChild(textEntity)
            previousCenterAnchor?.removeFromParent()
            arView.scene.addAnchor(textAnchor)
            previousCenterAnchor = textAnchor
            isUpdating = false
        }

        // let minimumPlaneDistance = 1.2 as Float
        // guard raycastDistance >= minimumPlaneDistance else {
        //     updateTextWithOrientation(cameraTransform)
        //     return
        // }

        nearbyFaceWithClassification(to: resultWorldPosition) { surface in
            DispatchQueue.main.async {
                if case let .some((faceTransform, _ /*classification*/)) = surface {
                    updateTextWithOrientation(Transform(matrix: faceTransform))
                } else {
                    updateTextWithOrientation(cameraTransform)
                }
            }
        }
    }

    let myWorkQueue = DispatchQueue(label: "RealityViewController")

    func nearbyFaceWithClassification(to location: SIMD3<Float>,
                                      completionBlock: @escaping ((simd_float4x4, ARMeshClassification)?) -> Void) {
        guard let anchors = arView.session.currentFrame?.anchors else {
            completionBlock(nil)
            return
        }

        // Perform the search asynchronously in order not to stall rendering.
        myWorkQueue.async {
            let cutoffDistance: Float = 4.0
            let meshAnchors = anchors
                .compactMap {
                    ($0 as? ARMeshAnchor).map { anchor in
                        (anchor: anchor, distance: distance(anchor.transform.position, location))
                    }
                }
                // Sort the mesh anchors by distance to the given location and filter out
                // any anchors that are too far away (4 meters is a safe upper limit).
                .filter { $0.distance <= cutoffDistance }
                .sorted { $0.distance < $1.distance }

            for (anchor, _) in meshAnchors {
                for index in 0..<anchor.geometry.faces.count {
                    // Get the center of the face so that we can compare it to the given location.
                    let geometricCenterOfFace = anchor.geometry.centerOf(faceWithIndex: index)

                    // Convert the face's center to world coordinates.
                    var centerLocalTransform = matrix_identity_float4x4
                    centerLocalTransform.columns.3 = SIMD4<Float>(geometricCenterOfFace.0, geometricCenterOfFace.1, geometricCenterOfFace.2, 1)
                    let centerWorldTransform = anchor.transform * centerLocalTransform
                    let centerWorldPosition = centerWorldTransform.position

                    // We're interested in a classification that is sufficiently close to the given location––within 5 cm.
                    let distanceToFace = distance(centerWorldPosition, location)
                    if distanceToFace <= 0.05 {
                        // Get the semantic classification of the face and finish the search.
                        let classification = anchor.geometry.classificationOf(faceWithIndex: index)
                        completionBlock((centerWorldTransform, classification))
                        return
                    }
                }
            }

            // Let the completion block know that no result was found.
            completionBlock(nil)
        }
    }

    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        updateRaycast()
    }

    private func updateForConfigs() {
        if showMesh {
            arView.debugOptions.insert(.showSceneUnderstanding)
        } else {
            arView.debugOptions.remove(.showSceneUnderstanding)
        }
    }

    // MARK: - Coaching

    public func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap { $0 }.joined(separator: "\n")
        DispatchQueue.main.async { [weak self] in
            let alertController = UIAlertController(title: "The AR session failed.",
                                                    message: errorMessage,
                                                    preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session",
                                              style: .default) {
                [weak self] _ in
                alertController.dismiss(animated: true, completion: nil)
                self?.resetARSession()
            }
            alertController.addAction(restartAction)
            self?.present(alertController, animated: true, completion: nil)
        }
    }

    let coachingOverlay = ARCoachingOverlayView()

    func setupCoachingOverlay() {
        // Set up coaching view
        coachingOverlay.session = arView.session
        coachingOverlay.delegate = self

        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(coachingOverlay)

        NSLayoutConstraint.activate([
            coachingOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            coachingOverlay.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            coachingOverlay.widthAnchor.constraint(equalTo: view.widthAnchor),
            coachingOverlay.heightAnchor.constraint(equalTo: view.heightAnchor)
        ])
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

    var arView: ARView {
        return view as! ARView
    }
    public override func loadView() {
        self.view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
    }

    public override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    public override var prefersStatusBarHidden: Bool {
        return true
    }
}
