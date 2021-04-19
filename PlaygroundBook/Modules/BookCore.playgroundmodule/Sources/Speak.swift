//
//  Speak.swift
//  BookCore
//
//  Created by Apollo Zhu on 4/17/21.
//

import Foundation
import AVFoundation

extension NumberFormatter {
    static func withDecimalPlaces(_ decimalPlaces: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = decimalPlaces
        return formatter
    }

    static func withDecimalPlaces(exactly decimalPlaces: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = decimalPlaces
        formatter.maximumFractionDigits = decimalPlaces
        return formatter
    }
}

extension String.StringInterpolation {
    public mutating func appendInterpolation(_ float: Float, decimalPlaces: Int) {
        appendLiteral(NumberFormatter.withDecimalPlaces(decimalPlaces)
                        .string(from: NSNumber(value: float))!)
    }
}

public class EnglishSpeaker: ObservableObject {
    @Published
    public var currentVoice: AVSpeechSynthesisVoice? = nil

    public let synthesizer = AVSpeechSynthesizer()

    public let voices = AVSpeechSynthesisVoice.speechVoices()
        // english only
        .filter { Locale(identifier: $0.language).languageCode == "en" }
        // sort by quality then by name
        .sorted {
            if $0.quality != $1.quality {
                return $0.quality.rawValue > $1.quality.rawValue
            } else {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

    private var speakCache: String? = nil

    public func speak(_ text: String, stopPrevious: Bool = true) {
        guard text != speakCache else { return }
        speakCache = text
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = currentVoice
        if synthesizer.isSpeaking && stopPrevious {
            synthesizer.stopSpeaking(at: .word)
        }
        synthesizer.speak(utterance)
    }

    public static let inCharge = EnglishSpeaker()
    private init() { }
}

public func say(_ text: String, stopPrevious: Bool = true) {
    EnglishSpeaker.inCharge.speak(text, stopPrevious: stopPrevious)
}
