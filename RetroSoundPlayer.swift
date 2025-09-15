#if canImport(AVFoundation)
import AVFoundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Generates simple retro sound effects using square waves.
/// The implementation uses `AVAudioSourceNode` so no external
/// audio assets are required.  The same class works on both
/// macOS and iOS.
final class RetroSoundPlayer {
    private let engine = AVAudioEngine()
    private let sampleRate: Double

    init() {
        sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        try? engine.start()
    }

    /// Core square-wave generator used by all effects.
    private func playSquareWave(duration: Double,
                                 baseFrequency: Double,
                                 pitchBend: ((Double) -> Double)? = nil) {
        var currentFrame: AVAudioFramePosition = 0
        let totalFrames = AVAudioFrameCount(duration * sampleRate)
        var finished = false

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let sample: Float
                if finished {
                    sample = 0
                } else {
                    let t = Double(currentFrame + AVAudioFramePosition(frame)) / self.sampleRate
                    let freq = pitchBend?(t) ?? baseFrequency
                    // Create a square wave by toggling between -0.8 and 0.8
                    let phase = t * freq
                    sample = fmod(phase, 1.0) < 0.5 ? 0.8 : -0.8
                }
                for buffer in abl {
                    let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)
                    ptr[frame] = sample
                }
            }
            currentFrame += AVAudioFramePosition(frameCount)
            if currentFrame >= AVAudioFramePosition(totalFrames) {
                finished = true
            }
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)

        // Detach the node after it finishes to free resources
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            if let engine = self?.engine {
                engine.disconnectNodeOutput(node)
                engine.detach(node)
            }
        }
    }

    /// Sword attack sound (0.3 seconds)
    func playAttackSound() {
        playSquareWave(duration: 0.3, baseFrequency: 880)
    }

    /// Door opening sound with quick upward pitch bend (0.6 seconds)
    func playDoorOpenSound() {
        playSquareWave(duration: 0.6, baseFrequency: 110) { t in
            // Bend from 110Hz to 220Hz in the first 0.1s
            let bendDuration = 0.1
            if t < bendDuration {
                return 110 + (220 - 110) * (t / bendDuration)
            } else {
                return 220
            }
        }
    }

    /// UI selection blip (0.1 seconds)
    func playButtonSelectSound() {
        playSquareWave(duration: 0.1, baseFrequency: 1320)
    }
}

// Example usage when running on macOS.  Plays all three sounds then exits.
#if os(macOS)
@main
class DemoApp: NSObject, NSApplicationDelegate {
    private let player = RetroSoundPlayer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        player.playAttackSound()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.player.playDoorOpenSound()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.player.playButtonSelectSound()
        }
        // Terminate after the last sound
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            NSApp.terminate(nil)
        }
    }
}
#endif
#endif
