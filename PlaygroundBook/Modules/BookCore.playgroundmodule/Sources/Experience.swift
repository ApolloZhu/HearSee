//
// Experience.swift
// GENERATED CONTENT. DO NOT EDIT.
//

import Foundation
import RealityKit
import simd
import Combine

@available(iOS 13.0, macOS 10.15, *)
public enum Experience {
    public enum LoadRealityFileError: Error {
        case fileNotFound(String)
    }

    private static var streams = [Combine.AnyCancellable]()

    public static func loadPin() throws -> Experience.Pin {
        guard let realityFileURL = Foundation.Bundle(for: Experience.Pin.self).url(forResource: "Experience", withExtension: "reality") else {
            throw Experience.LoadRealityFileError.fileNotFound("Experience.reality")
        }

        let realityFileSceneURL = realityFileURL.appendingPathComponent("Pin", isDirectory: false)
        let anchorEntity = try Experience.Pin.loadAnchor(contentsOf: realityFileSceneURL)
        return createPin(from: anchorEntity)
    }

    public static func loadPinAsync(completion: @escaping (Swift.Result<Experience.Pin, Swift.Error>) -> Void) {
        guard let realityFileURL = Foundation.Bundle(for: Experience.Pin.self).url(forResource: "Experience", withExtension: "reality") else {
            completion(.failure(Experience.LoadRealityFileError.fileNotFound("Experience.reality")))
            return
        }

        var cancellable: Combine.AnyCancellable?
        let realityFileSceneURL = realityFileURL.appendingPathComponent("Pin", isDirectory: false)
        let loadRequest = Experience.Pin.loadAnchorAsync(contentsOf: realityFileSceneURL)
        cancellable = loadRequest.sink(receiveCompletion: { loadCompletion in
            if case let .failure(error) = loadCompletion {
                completion(.failure(error))
            }
            streams.removeAll { $0 === cancellable }
        }, receiveValue: { entity in
            completion(.success(Experience.createPin(from: entity)))
        })
        cancellable?.store(in: &streams)
    }

    private static func createPin(from anchorEntity: RealityKit.AnchorEntity) -> Experience.Pin {
        let pin = Experience.Pin()
        pin.anchoring = anchorEntity.anchoring
        pin.addChild(anchorEntity)
        return pin
    }

    public class Pin: RealityKit.Entity, RealityKit.HasAnchoring {

        public var pin: RealityKit.Entity? {
            return self.findEntity(named: "Pin")
        }

    }

}
