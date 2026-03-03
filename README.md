# ⚠️ WARNING: USE AT YOUR OWN RISK ⚠️
> **This application directly accesses your MacBook's hardware sensors (lid angle / hinge). Any damage to your device caused by using this software is YOUR responsibility. The developers assume NO liability whatsoever. By using this software, you agree that you do so entirely at your own risk.**

---

# MAcordion 🪗
*Vibe coded by bruiselea*

Turn your MacBook into a fully functional accordion! **MAcordion** is a unique macOS application that uses your MacBook's built-in lid angle sensor (Hinge) to simulate the bellows of a real accordion. 

By opening and closing your Mac's screen, you control the airflow and dynamics of the sound. Play melodies on the keyboard while "pumping" the screen, just like a real instrument!

## Features
- **Native Hinge Sensor Integration**: Reads your MacBook's physical lid angle for dynamic bellows control.
- **Keyboard-Only Mode**: Works even without the hinge sensor — just press keys and play!
- **Dynamic Bellows Physics**: Volume, expression, and filter cutoff react to how fast you open or close the screen. 
- **Keyboard Instrument**: Play notes using your QWERTY keyboard.

## 🎹 Controls

| Key | Function |
|-----|----------|
| `A S D F G H J K L ;` | White keys (C D E F G A B C D E) |
| `W E T Y U O P` | Black keys (C# D# F# G# A# C# D#) |
| `Spacebar` | Air Valve — pump the bellows without sound |
| `Tab` | Toggle Sustain on/off |
| `Z` | Octave Down |
| `X` | Octave Up |

> **Note**: Make sure the MAcordion window is focused (click on it) before playing!

## Installation (DMG Release)

Since MAcordion requires deep hardware access to the lid angle sensor (IOHIDManager), it cannot run under the strict macOS App Sandbox required by the Mac App Store. 

### 📥 [>>> Download MAcordion.dmg <<<](https://github.com/bruiselea/MAcordion/releases/latest)

1. Download the latest `MAcordion.dmg` from the [Releases](https://github.com/bruiselea/MAcordion/releases) page.
2. Open the DMG and drag **MAcordion.app** into your `/Applications` folder.
3. Upon first launch, macOS may block the app because it is from an unidentified developer. 
    - Go to **System Settings > Privacy & Security**
    - Scroll down and click **Open Anyway** next to MAcordion.
4. Enjoy playing!

## Building from Source

Requirements:
- macOS 13.0+
- Xcode 15+ / Swift 5.9+

1. Clone the repository:
   ```bash
   git clone https://github.com/bruiselea/MAcordion.git
   ```
2. Build and run:
   ```bash
   cd MAcordion
   swift build && .build/debug/MAcordion
   ```
   Or open `Package.swift` in Xcode and press `Cmd + R`.

## Hinge Sensor (Optional)

The bellows feature (dynamic volume via lid angle) requires:
- Python 3 installed (`/usr/bin/python3`, `/opt/homebrew/bin/python3`, etc.)
- `pybooklid` package: `pip3 install pybooklid`

Without these, the app automatically runs in **Keyboard-Only Mode** — all keys produce sound at a fixed volume. Install `pybooklid` to unlock the full accordion experience!

## Architecture
MAcordion is built entirely in Swift and SwiftUI.
- **AudioEngine**: `AVAudioEngine` based sampler utilizing standard DLS/SoundFonts for classic accordion patches.
- **HingeMonitor**: Reads the MacBook lid angle sensor. Auto-detects Python and falls back to keyboard-only mode.
- **AccordionViewModel**: Handles the complex physics bridging the physical hinge velocity to MIDI expression/volume and filter bounds.

## License

This project is released under a custom, highly permissive license: **"Do whatever you want, as long as you provide credit."** 
See the [LICENSE](LICENSE) file for details.
