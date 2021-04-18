//
//  Speak.swift
//  BookCore
//
//  Created by Apollo Zhu on 4/17/21.
//

import Foundation
import AVFoundation

public let _synthesizer = AVSpeechSynthesizer()

private var speakCache: String? = nil
public func speak(
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
