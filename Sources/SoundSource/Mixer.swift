import AppKit
import CoreAudio
import SwiftUI

struct AudioApp: Identifiable {
    let id: String            // top-level .app path
    let name: String
    let icon: NSImage
    var processObjects: Set<AudioObjectID>
    var playing: Bool
}

@MainActor
final class Mixer: ObservableObject {
    static let maxVolume: Double = 4.0

    @Published private(set) var apps: [AudioApp] = []
    @Published var volumes: [String: Double] = [:]
    @Published var muted: Set<String> = []

    private var taps: [String: AppTap] = [:]
    private var timer: Timer?
    private let defaults = UserDefaults.standard

    init() {
        volumes = (defaults.dictionary(forKey: "volumes") as? [String: Double]) ?? [:]
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func volume(for id: String) -> Double { volumes[id] ?? 1.0 }

    func setVolume(_ v: Double, for id: String) {
        volumes[id] = v
        defaults.set(volumes, forKey: "volumes")
        apply(id)
    }

    func toggleMute(_ id: String) {
        if muted.contains(id) { muted.remove(id) } else { muted.insert(id) }
        apply(id)
    }

    func resetAll() {
        volumes.removeAll(); muted.removeAll()
        defaults.removeObject(forKey: "volumes")
        for id in Array(taps.keys) { apply(id) }
    }

    func shutdown() { taps.values.forEach { $0.stop() }; taps.removeAll() }

    private func effectiveGain(_ id: String) -> Float { muted.contains(id) ? 0 : Float(volume(for: id)) }
    private func needsTap(_ id: String) -> Bool { muted.contains(id) || abs(volume(for: id) - 1.0) > 0.001 }

    private func apply(_ id: String) {
        guard let app = apps.first(where: { $0.id == id }) else { return }
        if needsTap(id) {
            if let tap = taps[id], tap.processObjects == app.processObjects {
                tap.gain = effectiveGain(id)
            } else {
                taps[id]?.stop(); taps[id] = nil
                guard let uid = CA.defaultOutputUID() else { return }
                taps[id] = AppTap(processObjects: app.processObjects, outputUID: uid, gain: effectiveGain(id))
            }
        } else {
            taps[id]?.stop(); taps[id] = nil   // back to untouched system path
        }
    }

    private func refresh() {
        let sys = AudioObjectID(kAudioObjectSystemObject)
        var groups: [String: AudioApp] = [:]
        for obj in CA.objectList(sys, kAudioHardwarePropertyProcessObjectList) {
            let pid: pid_t = CA.get(obj, kAudioProcessPropertyPID, default: -1)
            let running: UInt32 = CA.get(obj, kAudioProcessPropertyIsRunningOutput, default: 0)
            guard pid > 0, let path = Self.executablePath(pid), let appPath = Self.topLevelApp(path),
                  !appPath.hasPrefix("/System/Library"), appPath != Bundle.main.bundlePath else { continue }
            if var g = groups[appPath] {
                g.processObjects.insert(obj); g.playing = g.playing || running != 0
                groups[appPath] = g
            } else {
                let url = URL(fileURLWithPath: appPath)
                let name = (Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                let icon = NSWorkspace.shared.icon(forFile: appPath)
                groups[appPath] = AudioApp(id: appPath, name: name, icon: icon, processObjects: [obj], playing: running != 0)
            }
        }
        // Like Windows' Volume Mixer: every app that has an audio session, playing ones first.
        apps = groups.values.sorted {
            $0.playing != $1.playing ? $0.playing
                : $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        // Rebuild taps whose process set or output device changed; start taps for restored settings.
        let uid = CA.defaultOutputUID()
        for app in apps {
            let existing = taps[app.id]
            if needsTap(app.id) {
                if existing == nil || existing!.processObjects != app.processObjects || existing!.outputUID != uid {
                    existing?.stop(); taps[app.id] = nil
                    apply(app.id)
                }
            }
        }
        for id in taps.keys where !apps.contains(where: { $0.id == id }) { taps[id]?.stop(); taps[id] = nil }
    }

    /// Helper processes (e.g. Chrome's audio helper) aren't NSRunningApplications, so use the path.
    private static func executablePath(_ pid: pid_t) -> String? {
        var buf = [CChar](repeating: 0, count: 4096)
        return proc_pidpath(pid, &buf, UInt32(buf.count)) > 0 ? String(cString: buf) : nil
    }

    private static func topLevelApp(_ path: String) -> String? {
        var parts: [String] = []
        for comp in path.split(separator: "/", omittingEmptySubsequences: true) {
            parts.append(String(comp))
            if comp.hasSuffix(".app") { return "/" + parts.joined(separator: "/") }
        }
        return nil
    }
}
