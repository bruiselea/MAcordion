"""
AcOrDiOn - Package Initialization
"""

from .config import *
from .keymaps import PIANO_KEY_MAP, BUTTON_KEY_MAP, get_key_map, MODE_NAMES
from .sound import SoundBank, midi_to_name, midi_to_frequency
from .hinge import HingeMonitor
from .ui import UI

__version__ = "1.0.0"
__author__ = "AcOrDiOn Team"
__description__ = "MacBook Accordion - 画面の動きで蛇腹を再現するアコーディオンアプリ"
