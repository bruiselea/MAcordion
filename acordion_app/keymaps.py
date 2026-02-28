"""
AcOrDiOn - Keyboard Mappings
キーボードマッピングの定義
"""

import pygame

# Piano Mode (GarageBand style)
# 白鍵: A S D F G H J K L ;
# 黒鍵: W E   T Y U   O P
PIANO_KEY_MAP = {
    # White keys (C D E F G A B C D E)
    pygame.K_a: 0,   # C
    pygame.K_s: 2,   # D
    pygame.K_d: 4,   # E
    pygame.K_f: 5,   # F
    pygame.K_g: 7,   # G
    pygame.K_h: 9,   # A
    pygame.K_j: 11,  # B
    pygame.K_k: 12,  # C (next octave)
    pygame.K_l: 14,  # D
    pygame.K_SEMICOLON: 16,  # E
    
    # Black keys (C# D# F# G# A# C# D#)
    pygame.K_w: 1,   # C#
    pygame.K_e: 3,   # D#
    pygame.K_t: 6,   # F#
    pygame.K_y: 8,   # G#
    pygame.K_u: 10,  # A#
    pygame.K_o: 13,  # C# (next octave)
    pygame.K_p: 15,  # D#
}

# Button Accordion Mode (B-System Chromatic)
# 3段のボタン配列、各段が短3度（3半音）ずれている
BUTTON_KEY_MAP = {
    # Row 1 (Q-P) - Top row
    pygame.K_q: 0,  pygame.K_w: 1,  pygame.K_e: 2,  pygame.K_r: 3,
    pygame.K_t: 4,  pygame.K_y: 5,  pygame.K_u: 6,  pygame.K_i: 7,
    pygame.K_o: 8,  pygame.K_p: 9,
    
    # Row 2 (A-;) - Middle row (offset by 3 semitones)
    pygame.K_a: 3,  pygame.K_s: 4,  pygame.K_d: 5,  pygame.K_f: 6,
    pygame.K_g: 7,  pygame.K_h: 8,  pygame.K_j: 9,  pygame.K_k: 10,
    pygame.K_l: 11, pygame.K_SEMICOLON: 12,
    
    # Row 3 (Z-/) - Bottom row (offset by 6 semitones)
    pygame.K_z: 6,  pygame.K_x: 7,  pygame.K_c: 8,  pygame.K_v: 9,
    pygame.K_b: 10, pygame.K_n: 11, pygame.K_m: 12, pygame.K_COMMA: 13,
    pygame.K_PERIOD: 14, pygame.K_SLASH: 15,
}

# Mode names for display
MODE_NAMES = ["Piano Mode", "Button Accordion (B-System)"]

def get_key_map(mode: int) -> dict:
    """Get the key mapping for the specified mode.
    
    Args:
        mode: 0 for Piano, 1 for Button Accordion
        
    Returns:
        Dictionary mapping pygame keys to note offsets
    """
    return BUTTON_KEY_MAP if mode == 1 else PIANO_KEY_MAP
