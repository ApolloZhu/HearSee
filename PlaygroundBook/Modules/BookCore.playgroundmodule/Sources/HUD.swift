//
//  HUD.swift
//  BookCore
//
//  Created by Apollo Zhu on 4/19/21.
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
