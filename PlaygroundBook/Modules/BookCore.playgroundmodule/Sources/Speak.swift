//
//  Speak.swift
//  BookCore
//
//  Created by Apollo Zhu on 4/17/21.
//

import Foundation
import AVFoundation

extension String.StringInterpolation {
    public mutating func appendInterpolation(_ float: Float, decimalPlaces: Int) {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = decimalPlaces
        appendLiteral(formatter.string(from: NSNumber(value: float))!)
    }
}

public let _synthesizer = AVSpeechSynthesizer()

#warning("TODO: offer UI for changing voice")
private var speakCache: String? = nil
public func say(
    _ text: String,
    using voice: AVSpeechSynthesisVoice? = nil,
    stopPrevious: Bool = true
) {
    guard text != speakCache else { return }
    speakCache = text
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = voice
    if _synthesizer.isSpeaking && stopPrevious {
        _synthesizer.stopSpeaking(at: .word)
    }
    _synthesizer.speak(utterance)
}
