# ⚠️ WARNING: USE AT YOUR OWN RISK ⚠️
> **This application directly accesses your MacBook's hardware sensors (lid angle / hinge). Any damage to your device caused by using this software is YOUR responsibility. The developers assume NO liability whatsoever. By using this software, you agree that you do so entirely at your own risk.**

---

# MAcordion 🪗
*Vibe coded by bruiselea*

Turn your MacBook into a fully functional accordion! **MAcordion** is a unique macOS application that uses your MacBook's built-in lid angle sensor (Hinge) to simulate the bellows of a real accordion. 

By opening and closing your Mac's screen, you control the airflow and dynamics of the sound. Play melodies on the keyboard while "pumping" the screen, just like a real instrument!


## Features
- **Native Hinge Sensor Integration**: Reads your MacBook's physical lid angle at a smooth 30Hz natively via IOKit—no external Python dependencies required!
- **Dynamic Bellows Physics**: Volume, expression, and filter cutoff frequencies naturally react to how fast you open or close the screen. 
- **Keyboard Instrument**: Map standard QWERTY keys to piano notes. 
    - `A S D F G ...` for white keys
    - `W E T Y U ...` for black keys
- **Performance Controls**:
    - `Spacebar`: Air Valve (pump the bellows without making sound)
    - `Tab`: Sustain
    - `Z / X`: Shift Octaves Up/Down

## Installation (DMG Release)

Since MAcordion requires deep hardware access to the lid angle sensor (IOHIDManager), it cannot run under the strict macOS App Sandbox required by the Mac App Store. 

1. Download the latest `MAcordion.dmg` from the [Releases](#) page.
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

## Architecture
MAcordion is built entirely in Swift and SwiftUI.
- **AudioEngine**: `AVAudioEngine` based sampler utilizing standard DLS/SoundFonts for classic accordion patches.
- **HingeMonitor**: Pure Swift `IOHIDManager` implementation that securely queries the Apple SMC / HID Orientation Sensor.
- **AccordionViewModel**: Handles the complex physics bridging the physical hinge velocity to MIDI expression/volume and filter bounds.

## License

This project is released under a custom, highly permissive license: **"Do whatever you want, as long as you provide credit."** 
See the [LICENSE](LICENSE) file for details.
