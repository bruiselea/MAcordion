# ⚠️ WARNING: USE AT YOUR OWN RISK ⚠️
> **This application directly accesses your MacBook's hardware sensors (lid angle / hinge) and microphone. Any damage to your device caused by using this software is YOUR responsibility. The developers assume NO liability whatsoever. By using this software, you agree that you do so entirely at your own risk.**

---

# MAcordion 🪗
*Vibe coded by bruiselea*

Turn your MacBook into a fully functional accordion — or, with Breath mode, into a melodica (鍵盤ハーモニカ / pianica). By opening and closing your Mac's screen (or by blowing into the microphone), you control the airflow and dynamics of the sound. Play melodies on the keyboard while "pumping" air, just like a real instrument.

![MAcordion performance interface](Design/macordion-studio-minimal-implementation.png)

## Highlights

- Native MacBook hinge sensor integration with no Python or Homebrew dependency
- Bellows movement mapped directly to the physical display angle
- Responsive keyboard performance while the hinge is moving
- Minimal graphite performance interface with live air-expression feedback
- Native Settings diagnostics for sensor status, hinge angle, and pressure
- Universal 2 release packages for Apple Silicon and Intel Macs

<details>
<summary>Sensor diagnostics</summary>

Open **MAcordion → Settings…** to inspect the live sensor state without adding
diagnostic clutter to the performance view.

<img src="Design/macordion-settings-diagnostics.png" alt="MAcordion sensor diagnostics settings" width="420">

</details>

## Launch Options

Three separate apps share the same audio engine and key mapping:

- **MAcordion** — bellows driven by the MacBook lid angle sensor (classic accordion).
- **MAcordionBreath** — bellows driven by microphone amplitude (melodica style).
- **MAcordionShisha** — bellows driven by the USB-C-to-Shisha differential-pressure sensor (ESP32-C3 firmware).

With Swift Package Manager:

```bash
swift run MAcordion        # Hinge sensor version
swift run MAcordionBreath  # Breath (microphone) version
swift run MAcordionShisha  # Shisha sensor version
```

If the bellows source is unavailable (no hinge sensor, no mic permission, no shisha device plugged in), the app falls back to a keyboard-only mode with fixed expression.

### Shisha sensor setup
Flash `firmware/esp32c3/shisha_sensor/shisha_sensor.ino` onto an ESP32-C3 Supermini wired to an MPXV7002DP via a 10k/27k divider, plug it in via USB-C, then `swift run MAcordionShisha`. The app auto-detects `/dev/cu.usbmodem*`. Override with `SHISHA_PORT=/dev/cu.usbmodemXXXX swift run MAcordionShisha` if multiple devices are connected.

## Controls

| Key | Function |
|-----|----------|
| `A S D F G H J K L ;` | White keys (C D E F G A B C D E) |
| `W E T Y U O P` | Black keys (C# D# F# G# A# C# D#) |
| `Spacebar` | Air Valve — pump the bellows without sound |
| `Tab` | Toggle Sustain on/off |
| `Z` | Octave Down |
| `X` | Octave Up |

> Make sure the MAcordion window has focus before playing.

## Requirements

- macOS 13.0+
- Swift 5.9+ / Xcode 15+
- Hinge version: a supported MacBook lid-angle sensor
- Breath version: microphone access (macOS will prompt on first launch)

## Reproducible release packages

Create signed application bundles and deterministic ZIP archives with:

```bash
./scripts/package.sh
```

The command builds Universal 2 binaries for Apple Silicon and Intel, then
writes all three release variants to `dist/`:

- `MAcordion-<version>-<architecture>.zip`
- `MAcordionBreath-<version>-<architecture>.zip`
- `MAcordionShisha-<version>-<architecture>.zip`
- `SHA256SUMS` and `BUILD-INFO.txt`

The default signature is ad hoc, so these local packages are not notarized.
On another Mac, Control-click the app and choose **Open** on first launch.
For normal Gatekeeper-approved distribution, set `SIGN_IDENTITY` to a
Developer ID Application certificate and notarize the resulting archive.
Version and build metadata can also be overridden:

```bash
APP_VERSION=1.4.0 BUILD_NUMBER=1 \
SIGN_IDENTITY="Developer ID Application: Example (TEAMID)" \
./scripts/package.sh
```

For byte-for-byte ZIP reproduction, use the same source revision, Xcode/Swift
toolchain, macOS SDK, CPU architecture, signing identity, and
`SOURCE_DATE_EPOCH`. The exact build environment is recorded in
`dist/BUILD-INFO.txt`.

To build only one architecture, set `ARCHITECTURES`, for example:

```bash
ARCHITECTURES=arm64 ./scripts/package.sh
```
