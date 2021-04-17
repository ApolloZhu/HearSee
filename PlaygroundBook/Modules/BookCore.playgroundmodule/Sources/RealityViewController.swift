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

    //    let distanceCircles: [ModelEntity] = [
    //        ModelEntity(mesh: .generateBox(size: 0.01), materials: [UnlitMaterial(color: .red)]),
    //        ModelEntity(mesh: .generateBox(size: 0.035), materials: [UnlitMaterial(color: .green)]),
    //        ModelEntity(mesh: .generateBox(size: 0.08), materials: [UnlitMaterial(color: .blue)]),
    //    ]

    private var previousCenterAnchor: AnchorEntity?

    private var raycast: ARTrackedRaycast? {
        didSet {
            oldValue?.stopTracking()
        }
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        updateForConfigs()
        setupCoachingOverlay()

        //        let cameraAnchor = AnchorEntity(.camera)       // ARCamera anchor
        //        cameraAnchor.addChild(try! DistanceRings.loadScene().distanceRing!)
        //        arView.scene.addAnchor(cameraAnchor)

        arView.debugOptions.insert(.showStatistics)

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

    private func updateRaycast() {
        guard let result = arView.raycast(from: arView.bounds.center,
                                          allowing: .estimatedPlane,
                                          alignment: .any).first
        else { return }
        func updateTextWithOrientation(_ orientation: Transform) {
            previousCenterAnchor?.removeFromParent()

            let raycastDistance = distance(result.worldTransform.position, arView.cameraTransform.translation)
            let textEntity = self.generateText(String(format: "%.1fm", raycastDistance), color: .systemPink)
            // 6. Scale the text depending on the distance,
            // such that it always appears with the same size on screen.
            textEntity.scale = .one * raycastDistance

            // 7. Place the text, facing the camera.
            let rayDirection = normalize(result.worldTransform.position - arView.cameraTransform.translation)
            let textPositionInWorldCoordinates = result.worldTransform.position - (rayDirection * 0.1)
            var finalTransform = orientation
            finalTransform.translation = textPositionInWorldCoordinates
            let textAnchor = AnchorEntity(world: finalTransform.matrix)
            textAnchor.addChild(textEntity)
            arView.scene.addAnchor(textAnchor)
            previousCenterAnchor = textAnchor
        }

        nearbyFaceWithClassification(to: result.worldTransform.position) {
            [weak self] surface in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if case let .some((faceTransform, classification)) = surface {
                    let transform = Transform(matrix: faceTransform)
    //                print(transform, self.arView.cameraTransform)
                    updateTextWithOrientation(transform)
                } else {
                    updateTextWithOrientation(self.arView.cameraTransform)
                }
            }
        }
    }

    func nearbyFaceWithClassification(to location: SIMD3<Float>,
                                      completionBlock: @escaping ((simd_float4x4, ARMeshClassification)?) -> Void) {
        guard let frame = arView.session.currentFrame else {
            completionBlock(nil)
            return
        }

        var meshAnchors = frame.anchors.compactMap({ $0 as? ARMeshAnchor })

        // Sort the mesh anchors by distance to the given location and filter out
        // any anchors that are too far away (4 meters is a safe upper limit).
        let cutoffDistance: Float = 4.0
        meshAnchors.removeAll { distance($0.transform.position, location) > cutoffDistance }
        meshAnchors.sort { distance($0.transform.position, location) < distance($1.transform.position, location) }

        // Perform the search asynchronously in order not to stall rendering.
        DispatchQueue.global().async {
            for anchor in meshAnchors {
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
