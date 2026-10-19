import SwiftUI

@main
struct SoundSourceApp: App {
    @StateObject private var mixer = Mixer()

    var body: some Scene {
        MenuBarExtra("SoundSource", systemImage: "slider.vertical.3") {
            MixerView(mixer: mixer)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MixerView: View {
    @ObservedObject var mixer: Mixer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sound Source").font(.headline)
            if mixer.apps.isEmpty {
                Text("ยังไม่มีแอปที่ใช้เสียง")
                    .foregroundStyle(.secondary).font(.callout)
            }
            ForEach(mixer.apps) { app in
                AppRow(mixer: mixer, app: app)
            }
            Divider()
            HStack {
                Button("Reset all") { mixer.resetAll() }
                Spacer()
                Button("Quit") { mixer.shutdown(); NSApplication.shared.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 340)
    }
}

struct AppRow: View {
    @ObservedObject var mixer: Mixer
    let app: AudioApp

    var body: some View {
        let muted = mixer.muted.contains(app.id)
        let vol = mixer.volume(for: app.id)
        HStack(spacing: 8) {
            Image(nsImage: app.icon).resizable().frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(app.name).lineLimit(1)
                    if app.playing { Image(systemName: "waveform").foregroundStyle(.green).font(.caption) }
                    Spacer()
                    Text(muted ? "Muted" : "\(Int(vol * 100))%")
                        .monospacedDigit().foregroundStyle(vol > 1 && !muted ? .orange : .secondary)
                        .font(.caption)
                }
                Slider(value: Binding(get: { vol }, set: { mixer.setVolume($0, for: app.id) }),
                       in: 0...Mixer.maxVolume)
                    .disabled(muted)
            }
            Button { mixer.toggleMute(app.id) } label: {
                Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            }.buttonStyle(.borderless)
        }
    }
}
