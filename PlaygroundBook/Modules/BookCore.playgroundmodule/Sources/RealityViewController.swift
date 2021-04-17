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
        arView.session.run(configuration)
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
