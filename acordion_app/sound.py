"""
AcOrDiOn - Sound Generator
アコーディオン音の生成モジュール
"""

import numpy as np
import pygame
from typing import Dict

from .config import (
    SAMPLE_RATE, SOUND_DURATION, NOTE_NAMES,
    ACCORDION_DETUNE_SHARP, ACCORDION_DETUNE_FLAT,
    ACCORDION_TREMOLO_RATE, ACCORDION_HARMONICS,
    MIN_OCTAVE, MAX_OCTAVE
)


def midi_to_frequency(midi_note: int) -> float:
    """Convert MIDI note number to frequency in Hz.
    
    Args:
        midi_note: MIDI note number (60 = C4, 69 = A4 = 440Hz)
        
    Returns:
        Frequency in Hz
    """
    return 440.0 * (2.0 ** ((midi_note - 69) / 12.0))


def midi_to_name(midi_note: int) -> str:
    """Convert MIDI note number to note name.
    
    Args:
        midi_note: MIDI note number
        
    Returns:
        Note name string (e.g., "C4", "A#3")
    """
    octave = midi_note // 12 - 1
    note_name = NOTE_NAMES[midi_note % 12]
    return f"{note_name}{octave}"


def generate_accordion_tone(frequency: float) -> pygame.mixer.Sound:
    """Generate a realistic accordion reed sound.
    
    The accordion sound is created using additive synthesis with:
    - Multiple detuned reeds (musette tuning) for tremolo effect
    - Sawtooth-like harmonic content for brightness
    - Subtle bellows noise
    - Quick attack envelope
    
    Args:
        frequency: Fundamental frequency in Hz
        
    Returns:
        pygame.mixer.Sound object
    """
    n_samples = int(SAMPLE_RATE * SOUND_DURATION)
    t = np.linspace(0, SOUND_DURATION, n_samples, False)
    
    wave = np.zeros(n_samples)
    
    # Reed 1: Main fundamental with sawtooth-like harmonics
    for h in range(1, ACCORDION_HARMONICS + 1):
        amp = 0.5 / h
        wave += amp * np.sin(2 * np.pi * frequency * h * t)
    
    # Reed 2: Slightly sharp (creates musette tremolo)
    for h in range(1, 8):
        amp = 0.4 / h
        wave += amp * np.sin(2 * np.pi * frequency * ACCORDION_DETUNE_SHARP * h * t)
    
    # Reed 3: Slightly flat
    for h in range(1, 8):
        amp = 0.4 / h
        wave += amp * np.sin(2 * np.pi * frequency * ACCORDION_DETUNE_FLAT * h * t)
    
    # Bellows air noise (very subtle)
    noise = np.random.randn(n_samples) * 0.015
    noise_filtered = np.convolve(noise, np.ones(80) / 80, mode='same')
    wave += noise_filtered
    
    # Tremolo from reed beating
    tremolo = 1 + 0.04 * np.sin(2 * np.pi * ACCORDION_TREMOLO_RATE * t)
    wave = wave * tremolo
    
    # Quick attack envelope (8ms)
    attack_samples = int(0.008 * SAMPLE_RATE)
    wave[:attack_samples] *= np.linspace(0, 1, attack_samples)
    
    # Normalize
    wave = wave / np.max(np.abs(wave)) * 0.45
    
    # Convert to 16-bit stereo
    wave_int = (wave * 32767).astype(np.int16)
    stereo = np.column_stack((wave_int, wave_int))
    
    return pygame.sndarray.make_sound(stereo)


class SoundBank:
    """Manages accordion sound generation and playback."""
    
    def __init__(self):
        """Initialize the sound bank."""
        self.sounds: Dict[int, pygame.mixer.Sound] = {}
        self.channels: Dict[int, pygame.mixer.Channel] = {}
        
    def generate_all_sounds(self, callback=None):
        """Generate sounds for all notes.
        
        Args:
            callback: Optional function to call with progress (octave number)
        """
        for octave in range(MIN_OCTAVE, MAX_OCTAVE + 1):
            if callback:
                callback(octave)
            for note_idx in range(12):
                midi_note = octave * 12 + note_idx
                frequency = midi_to_frequency(midi_note)
                self.sounds[midi_note] = generate_accordion_tone(frequency)
    
    def play_note(self, midi_note: int, volume: float) -> bool:
        """Start playing a note.
        
        Args:
            midi_note: MIDI note number to play
            volume: Volume level (0.0 to 1.0)
            
        Returns:
            True if note started successfully
        """
        if midi_note not in self.sounds:
            return False
            
        channel = pygame.mixer.find_channel(True)
        if channel:
            vol = max(0.1, min(1.0, volume))
            channel.set_volume(vol, vol)
            channel.play(self.sounds[midi_note], loops=-1)
            self.channels[midi_note] = channel
            return True
        return False
    
    def stop_note(self, midi_note: int, fadeout_ms: int = 100):
        """Stop playing a note.
        
        Args:
            midi_note: MIDI note number to stop
            fadeout_ms: Fadeout duration in milliseconds
        """
        if midi_note in self.channels:
            self.channels[midi_note].fadeout(fadeout_ms)
            del self.channels[midi_note]
    
    def stop_all_notes(self, fadeout_ms: int = 80):
        """Stop all playing notes.
        
        Args:
            fadeout_ms: Fadeout duration in milliseconds
        """
        for channel in self.channels.values():
            channel.fadeout(fadeout_ms)
        self.channels.clear()
    
    def update_volumes(self, volume: float):
        """Update volume for all playing notes.
        
        Args:
            volume: New volume level (0.0 to 1.0)
        """
        actual_vol = max(0.05, min(1.0, volume))
        for midi_note, channel in list(self.channels.items()):
            if channel.get_busy():
                if midi_note in self.sounds:
                    self.sounds[midi_note].set_volume(actual_vol)
                channel.set_volume(actual_vol, actual_vol)
    
    def get_active_notes(self) -> set:
        """Get set of currently playing MIDI note numbers."""
        return set(self.channels.keys())
