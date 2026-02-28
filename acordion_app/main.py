#!/usr/bin/env python3
"""
AcOrDiOn - MacBook Accordion
アコーディオンとしてMacBookを使うアプリケーション

Usage:
    python main.py

画面の動きが蛇腹として機能し、キーボードで音を出します。
"""

import pygame
import sys

from acordion_app import (
    WINDOW_WIDTH, WINDOW_HEIGHT, FPS, AUDIO_BUFFER,
    MIN_OCTAVE, MAX_OCTAVE, DEFAULT_OCTAVE,
    get_key_map, SoundBank, HingeMonitor, UI
)


class AccordionApp:
    """Main application class for AcOrDiOn."""
    
    def __init__(self):
        """Initialize the accordion application."""
        # Initialize pygame
        pygame.init()
        pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=AUDIO_BUFFER)
        pygame.mixer.set_num_channels(32)
        
        # Create window
        self.screen = pygame.display.set_mode((WINDOW_WIDTH, WINDOW_HEIGHT))
        pygame.display.set_caption("AcOrDiOn - MacBook Accordion")
        self.clock = pygame.time.Clock()
        
        # Initialize components
        self.sound_bank = SoundBank()
        self.hinge_monitor = HingeMonitor()
        self.ui = UI(self.screen)
        
        # State
        self.mode = 0  # 0 = Piano, 1 = Button Accordion
        self.octave = DEFAULT_OCTAVE
        self.active_notes = set()
        self.sustain = False
        self.running = True
        
        # Generate sounds
        print("AcOrDiOn - Generating accordion sounds...")
        self.sound_bank.generate_all_sounds(
            callback=lambda o: print(f"  Generating octave {o}...")
        )
        print("Sound generation complete!\n")
        
        # Start hinge monitoring
        if self.hinge_monitor.is_available:
            print("Hinge sensor: AVAILABLE")
            self.hinge_monitor.start()
        else:
            print("Hinge sensor: NOT AVAILABLE")
        
        self._print_instructions()
    
    def _print_instructions(self):
        """Print usage instructions to console."""
        print("\n" + "=" * 50)
        print("AcOrDiOn - MacBook Accordion")
        print("=" * 50)
        print("\nModes:")
        print("  1 = Piano Mode (GarageBand layout)")
        print("  2 = Button Accordion (B-System)")
        print("\nControls:")
        print("  [ / ] = Change octave")
        print("  Tab   = Toggle sustain")
        print("  Esc   = Quit")
        print("\nMove the screen like accordion bellows!")
        print("=" * 50 + "\n")
    
    def run(self):
        """Main application loop."""
        try:
            while self.running:
                self._handle_events()
                self._update()
                self._draw()
                self.clock.tick(FPS)
        finally:
            self._cleanup()
    
    def _handle_events(self):
        """Process pygame events."""
        key_map = get_key_map(self.mode)
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.running = False
            
            elif event.type == pygame.KEYDOWN:
                self._handle_keydown(event.key, key_map)
            
            elif event.type == pygame.KEYUP:
                self._handle_keyup(event.key, key_map)
    
    def _handle_keydown(self, key: int, key_map: dict):
        """Handle key press events."""
        # Mode switching
        if key == pygame.K_1:
            self._switch_mode(0)
        elif key == pygame.K_2:
            self._switch_mode(1)
        
        # Octave control
        elif key in (pygame.K_MINUS, pygame.K_LEFTBRACKET):
            self.octave = max(MIN_OCTAVE, self.octave - 1)
        elif key in (pygame.K_EQUALS, pygame.K_RIGHTBRACKET):
            self.octave = min(MAX_OCTAVE, self.octave + 1)
        
        # Sustain
        elif key == pygame.K_TAB:
            self.sustain = not self.sustain
            if not self.sustain:
                self._all_notes_off()
        
        # Quit
        elif key == pygame.K_ESCAPE:
            self.running = False
        
        # Note keys
        elif key in key_map:
            self._note_on(key_map[key])
    
    def _handle_keyup(self, key: int, key_map: dict):
        """Handle key release events."""
        if key in key_map:
            self._note_off(key_map[key])
    
    def _switch_mode(self, mode: int):
        """Switch keyboard mode."""
        if self.mode != mode:
            self._all_notes_off()
            self.mode = mode
    
    def _note_on(self, note_offset: int):
        """Start playing a note."""
        midi_note = 60 + (self.octave - 4) * 12 + note_offset
        midi_note = max(24, min(96, midi_note))
        
        if midi_note not in self.active_notes:
            self.active_notes.add(midi_note)
            self.sound_bank.play_note(midi_note, self.hinge_monitor.volume)
    
    def _note_off(self, note_offset: int):
        """Stop playing a note."""
        midi_note = 60 + (self.octave - 4) * 12 + note_offset
        midi_note = max(24, min(96, midi_note))
        
        if midi_note in self.active_notes and not self.sustain:
            self.active_notes.discard(midi_note)
            self.sound_bank.stop_note(midi_note)
    
    def _all_notes_off(self):
        """Stop all playing notes."""
        self.active_notes.clear()
        self.sound_bank.stop_all_notes()
    
    def _update(self):
        """Update application state."""
        # Update volumes based on hinge position
        self.sound_bank.update_volumes(self.hinge_monitor.volume)
    
    def _draw(self):
        """Render the UI."""
        self.ui.draw(
            mode=self.mode,
            octave=self.octave,
            current_angle=self.hinge_monitor.current_angle,
            angular_velocity=self.hinge_monitor.angular_velocity,
            volume=self.hinge_monitor.volume,
            active_notes=self.active_notes,
            sustain=self.sustain,
            hinge_available=self.hinge_monitor.is_available
        )
    
    def _cleanup(self):
        """Clean up resources."""
        print("\nShutting down...")
        self._all_notes_off()
        self.hinge_monitor.stop()
        pygame.mixer.quit()
        pygame.quit()


def main():
    """Entry point for the application."""
    app = AccordionApp()
    app.run()


if __name__ == "__main__":
    main()
