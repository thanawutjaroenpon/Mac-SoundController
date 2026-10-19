import CoreAudio
import Foundation

/// Captures the audio of a group of processes (muting the original path),
/// applies a gain with a soft limiter, and plays it on the output device.
final class AppTap {
    let outputUID: String
    let processObjects: Set<AudioObjectID>

    private let target = UnsafeMutablePointer<Float>.allocate(capacity: 1)
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private let queue = DispatchQueue(label: "soundsource.io", qos: .userInteractive)

    var gain: Float {
        get { target.pointee }
        set { target.pointee = newValue }
    }

    init?(processObjects: Set<AudioObjectID>, outputUID: String, gain: Float) {
        self.processObjects = processObjects
        self.outputUID = outputUID
        target.initialize(to: gain)

        let desc = CATapDescription(stereoMixdownOfProcesses: Array(processObjects))
        desc.uuid = UUID()
        desc.muteBehavior = .mutedWhenTapped
        desc.isPrivate = true
        guard AudioHardwareCreateProcessTap(desc, &tapID) == noErr else { cleanup(); return nil }

        let aggDict: [String: Any] = [
            kAudioAggregateDeviceNameKey: "SoundSource-\(desc.uuid.uuidString.prefix(8))",
            kAudioAggregateDeviceUIDKey: "soundsource.agg.\(desc.uuid.uuidString)",
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: desc.uuid.uuidString,
            ]],
        ]
        guard AudioHardwareCreateAggregateDevice(aggDict as CFDictionary, &aggID) == noErr else { cleanup(); return nil }

        var current: Float = gain
        let tgt = target
        let status = AudioDeviceCreateIOProcIDWithBlock(&procID, aggID, queue) { _, inInput, _, outOutput, _ in
            let ins = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inInput))
            let outs = UnsafeMutableAudioBufferListPointer(outOutput)
            let goal = tgt.pointee
            let start = current
            for i in 0..<outs.count {
                guard let dst = outs[i].mData?.assumingMemoryBound(to: Float.self) else { continue }
                let dstCount = Int(outs[i].mDataByteSize) / MemoryLayout<Float>.size
                guard i < ins.count, let src = ins[i].mData?.assumingMemoryBound(to: Float.self) else {
                    memset(dst, 0, Int(outs[i].mDataByteSize)); continue
                }
                let n = min(dstCount, Int(ins[i].mDataByteSize) / MemoryLayout<Float>.size)
                let step = n > 0 ? (goal - start) / Float(n) : 0
                var g = start
                for k in 0..<n {
                    g += step
                    let y = src[k] * g
                    let a = abs(y)
                    // soft limiter above 0.9 so boosted audio doesn't hard-clip
                    dst[k] = a > 0.9 ? (y < 0 ? -1 : 1) * (0.9 + 0.1 * tanhf((a - 0.9) / 0.1)) : y
                }
                if n < dstCount { memset(dst + n, 0, (dstCount - n) * MemoryLayout<Float>.size) }
            }
            current = goal
        }
        guard status == noErr, let procID, AudioDeviceStart(aggID, procID) == noErr else { cleanup(); return nil }
    }

    private func cleanup() {
        if aggID != kAudioObjectUnknown {
            if let procID { AudioDeviceStop(aggID, procID); AudioDeviceDestroyIOProcID(aggID, procID) }
            AudioHardwareDestroyAggregateDevice(aggID)
        }
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID) }
        procID = nil; aggID = AudioObjectID(kAudioObjectUnknown); tapID = AudioObjectID(kAudioObjectUnknown)
    }

    func stop() { cleanup() }

    deinit { cleanup(); target.deallocate() }
}
