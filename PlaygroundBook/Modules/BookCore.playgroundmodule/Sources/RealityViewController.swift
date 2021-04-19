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

struct VoiceChanger: View {
    @ObservedObject
    var voicing: EnglishSpeaker = .inCharge
    @State
    private var showingVoiceChanger: Bool = false
    var body: some View {
        Button {
            showingVoiceChanger = true
        } label: {
            Text("Change Voice")
                .padding()
        }
        .actionSheet(isPresented: $showingVoiceChanger) {
            ActionSheet(title: Text("Choose Voice"), message: nil,
                        buttons: voicing.voices.map { voice in
                            return .default(Text(voice.name)) {
                                voicing.currentVoice = voice
                            }
                        })
        }
    }
}

struct HUD: View {
    @ObservedObject
    var dataSource: RealityViewController

    private let formatter = NumberFormatter.withDecimalPlaces(exactly: 2)

    var distanceList: some View {
        ForEach(ARMeshClassification.allCases, id: \.rawValue) { classification in
            if let pair = dataSource._anchorSummary?.minDistanceToCamera[classification] {
                HStack {
                    Text(classification.description)
                        .fontWeight(.bold)
                    Spacer()
                    Text("\(NSNumber(value: pair.inMeters), formatter: formatter) m")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(Color(dataSource.state.colorForDistance(pair.inMeters)))
                }
            }
        }
    }


    var body: some View {
        VStack {
            HStack {
                Spacer()
                HStack {
                    VoiceChanger()
                    Divider()
                    Button {
                        dataSource.resetARSession()
                    } label: {
                        Text("Reset Tracking")
                            .foregroundColor(.red)
                            .padding()
                    }
                }
                .foregroundColor(.primary)
                .fixedSize()
                .background(VisualEffectBlur())
                .cornerRadius(10)
                .padding()
            }
            Spacer()
            HStack {
                Spacer()
                VStack(alignment: .leading) {
                    Text("Nearest Distances")
                        .font(.title)
                        .padding(.bottom)

                    if dataSource._anchorSummary?.minDistanceToCamera.isEmpty == false {
                        distanceList
                    } else {
                        Text("Detecting...")
                    }
                }
                .fixedSize()
                .padding()
                .background(VisualEffectBlur(blurStyle: .systemThinMaterial))
                .cornerRadius(10)
                .padding()
            }
        }
    }
}

public class RealityViewController: UIViewController,
                                    ARSessionDelegate, ARCoachingOverlayViewDelegate,
                                    ObservableObject {
    internal struct State {
        var showMesh: Bool = false
        var showDistance: Bool = false
        var didReceiveDistanceFromCameraToPointInWorldAtCenterOfView: ((Float) -> Void)? = nil
        var didReceiveMinDistanceFromCamera: (([ARMeshClassification: Float]) -> Void)? = nil
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

    //    private lazy var minDistanceAnchor: AnchorEntity = {
    //        let entity = AnchorEntity(world: [0, 0, 0])
    //        let pin = try! Experience.loadPin().pin!
    //        entity.addChild(pin)
    //        arView.scene.addAnchor(entity)
    //        return entity
    //    }()
    private var previousCenterAnchor: AnchorEntity?
    private var isUpdating = false
    private func updateRaycast() {
        if isUpdating || !state.showDistance { return }
        isUpdating = true
        guard let raycastResult = arView.raycast(from: arView.bounds.center,
                                                 allowing: .estimatedPlane,
                                                 alignment: .any).first
        else { isUpdating = false; return }

        let cameraTransform = arView.cameraTransform
        let resultWorldPosition = raycastResult.worldTransform.position
        let raycastDistance = distance(resultWorldPosition, cameraTransform.translation)
        let rayDirection = normalize(resultWorldPosition - cameraTransform.translation)
        let textPositionInWorldCoordinates = resultWorldPosition - (rayDirection * 0.1)

        func updateTextWithOrientation() {
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
            let textAnchor = AnchorEntity(world: transform.matrix)
            textAnchor.addChild(textEntity)
            previousCenterAnchor?.removeFromParent()
            arView.scene.addAnchor(textAnchor)
            previousCenterAnchor = textAnchor
            state.didReceiveDistanceFromCameraToPointInWorldAtCenterOfView?(raycastDistance)
            isUpdating = false
        }

        processAllAnchors(centerWorldPosition: resultWorldPosition) { [weak self] result in
            let raycastClassification: ARMeshClassification
                = raycastResult.anchor
                .flatMap { $0 as? ARPlaneAnchor }
                .map { ARMeshClassification($0.classification) }
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
                self?.state.didReceiveMinDistanceFromCamera?(distances)
            }
        }
        updateTextWithOrientation()
    }

    // func updateCategorizedAnchors(_ distances: [ARMeshClassification : (inMeters: Float, worldTransform: simd_float4x4)]) {
    //     for (classification, point) in distances {
    //         let anchor = self.anchor(forClassification: classification)
    //         anchor.setTransformMatrix(point.worldTransform, relativeTo: nil)
    //     }
    // }

    public struct AnchorSummary {
        let center: (worldTransform: simd_float4x4, classification: ARMeshClassification)?
        let minDistanceToCamera: [ARMeshClassification: (inMeters: Float, worldTransform: simd_float4x4)]
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

            var minDistanceToCamera: [ARMeshClassification: (inMeters: Float, worldTransform: simd_float4x4)] = [:]

            // Use O(n) instead O(n log n) sorting so processing anchors are faster
            for case let anchor as ARMeshAnchor in anchors {
                let distanceToPOI = distance(anchor.transform.position, location)
                guard distanceToPOI < centerPointCutoffDistance else { continue }

                for index in 0..<anchor.geometry.faces.count {
                    // Get the center of the face so that we can compare it to the given location.
                    let geometricCenterOfFace = anchor.geometry.centerOf(faceWithIndex: index)

                    // Convert the face's center to world coordinates.
                    var centerLocalTransform = matrix_identity_float4x4
                    // translationMatrixOf(
                    //     normal: anchor.geometry.normalOf(faceWithIndex: index),
                    //     at: geometricCenterOfFace
                    // )
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
        // arView.environment.sceneUnderstanding.options = [.occlusion, .physics,]
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
            previousCenterAnchor?.removeFromParent()
        }
        hud.view.isHidden = (state.didReceiveMinDistanceFromCamera == nil)

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

    //    private var _anchorCache: [ARMeshClassification: AnchorEntity] = [:]
    //    func anchor(forClassification classification: ARMeshClassification) -> AnchorEntity {
    //        if let anchor = _anchorCache[classification] {
    //            return anchor
    //        } else {
    //            let anchor = AnchorEntity()
    //            _anchorCache[classification] = anchor
    //            arView.scene.addAnchor(anchor)
    //            anchor.playAudio(try! AudioFileResource.load(named: "80s Back Beat 02.caf", shouldLoop: true))
    //            return anchor
    //        }
    //    }

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
