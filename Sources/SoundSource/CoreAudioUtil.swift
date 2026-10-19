import CoreAudio
import Foundation

enum CA {
    static func address(_ sel: AudioObjectPropertySelector,
                        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: sel, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    static func get<T>(_ obj: AudioObjectID, _ sel: AudioObjectPropertySelector, default def: T) -> T {
        var addr = address(sel)
        var value = def
        var size = UInt32(MemoryLayout<T>.size)
        let status = AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, &value)
        return status == noErr ? value : def
    }

    static func objectList(_ obj: AudioObjectID, _ sel: AudioObjectPropertySelector) -> [AudioObjectID] {
        var addr = address(sel)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(obj, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        var list = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, &list) == noErr else { return [] }
        return list
    }

    static func string(_ obj: AudioObjectID, _ sel: AudioObjectPropertySelector) -> String? {
        var addr = address(sel)
        var cf: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, &cf) == noErr, let cf else { return nil }
        return cf.takeRetainedValue() as String
    }

    static func defaultOutputUID() -> String? {
        let dev: AudioObjectID = get(AudioObjectID(kAudioObjectSystemObject),
                                     kAudioHardwarePropertyDefaultOutputDevice,
                                     default: AudioObjectID(kAudioObjectUnknown))
        guard dev != kAudioObjectUnknown else { return nil }
        return string(dev, kAudioDevicePropertyDeviceUID)
    }

    static func processObject(forPID pid: pid_t) -> AudioObjectID {
        var addr = address(kAudioHardwarePropertyTranslatePIDToProcessObject)
        var pidVar = pid
        var obj = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        _ = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr,
                                       UInt32(MemoryLayout<pid_t>.size), &pidVar, &size, &obj)
        return obj
    }
}
