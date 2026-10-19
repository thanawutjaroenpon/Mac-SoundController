# mac-soundcontroller

Menu bar app for macOS that works like Windows' Volume Mixer: per-app volume, mute, and boost up to 400%.

It uses Core Audio process taps (macOS 14.2+), so no audio driver is needed. Helper processes (Chrome, Discord, ...) are grouped under their parent app.

## Build

```sh
./make_dmg.sh   # builds build/SoundSource.app and build/SoundSource.dmg
```

Requires Swift (Xcode Command Line Tools). On first use, allow System Audio Recording. The app is ad-hoc signed; right-click > Open if Gatekeeper complains.
