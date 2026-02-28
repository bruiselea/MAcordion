"""
AcOrDiOn - Configuration
設定値の定義
"""

# Window Settings
WINDOW_WIDTH = 800
WINDOW_HEIGHT = 650
FPS = 60

# Audio Settings
SAMPLE_RATE = 44100
SOUND_DURATION = 4.0  # seconds
AUDIO_BUFFER = 256

# Colors (RGB)
COLORS = {
    'background': (26, 26, 46),
    'text': (255, 255, 255),
    'accent': (100, 200, 255),
    'active_note': (80, 200, 120),
    'warning': (255, 150, 50),
    'mode_indicator': (255, 100, 100),
    'inactive': (80, 80, 80),
    'hint_text': (140, 140, 160),
}

# Hinge Sensor Settings
HINGE_POLL_RATE = 66  # Hz
HINGE_HISTORY_SIZE = 3  # Number of samples for smoothing
VELOCITY_SMOOTHING = 0.5  # Lower = more responsive
VOLUME_SMOOTHING = 0.3  # Lower = more responsive

# Note Names
NOTE_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']

# Accordion Sound Parameters
ACCORDION_DETUNE_SHARP = 1.006  # ~10 cents
ACCORDION_DETUNE_FLAT = 0.994
ACCORDION_TREMOLO_RATE = 4  # Hz
ACCORDION_HARMONICS = 12  # Number of harmonics

# Octave Range
MIN_OCTAVE = 2
MAX_OCTAVE = 6
DEFAULT_OCTAVE = 4
