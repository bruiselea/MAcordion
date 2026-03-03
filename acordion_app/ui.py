"""
AcOrDiOn - User Interface
pygame UIのモジュール
"""

import pygame
from typing import Set, Tuple

from .config import (
    WINDOW_WIDTH, WINDOW_HEIGHT, COLORS, NOTE_NAMES,
    MIN_OCTAVE, MAX_OCTAVE
)
from .keymaps import MODE_NAMES


class UI:
    """Handles all UI rendering for the accordion app."""
    
    def __init__(self, screen: pygame.Surface):
        """Initialize the UI.
        
        Args:
            screen: pygame display surface
        """
        self.screen = screen
        
        # Initialize fonts
        self.font_large = pygame.font.SysFont("Arial", 42)
        self.font_medium = pygame.font.SysFont("Arial", 28)
        self.font_small = pygame.font.SysFont("Arial", 20)
    
    def draw(
        self,
        mode: int,
        octave: int,
        current_angle: float,
        angular_velocity: float,
        volume: float,
        active_notes: Set[int],
        sustain: bool,
        hinge_available: bool
    ):
        """Draw the entire UI.
        
        Args:
            mode: Current mode (0=Piano, 1=Button)
            octave: Current octave
            current_angle: Current hinge angle
            angular_velocity: Current angular velocity
            volume: Current bellows volume
            active_notes: Set of currently playing MIDI notes
            sustain: Whether sustain is on
            hinge_available: Whether hinge sensor is available
        """
        self.screen.fill(COLORS['background'])
        
        self._draw_header(mode)
        self._draw_hinge_status(current_angle, angular_velocity, hinge_available)
        self._draw_volume_bar(volume)
        self._draw_active_notes(active_notes)
        self._draw_octave(octave)
        self._draw_sustain(sustain)
        self._draw_keyboard_hints(mode)
        self._draw_footer()
        
        pygame.display.flip()
    
    def _draw_header(self, mode: int):
        """Draw title and mode indicator."""
        # Title
        title = self.font_large.render("AcOrDiOn", True, COLORS['text'])
        self._center_text(title, 15)
        
        # Mode
        mode_text = self.font_medium.render(
            f"Mode: {MODE_NAMES[mode]}", True, COLORS['mode_indicator']
        )
        self._center_text(mode_text, 60)
        
        # Mode hint
        hint = self.font_small.render(
            "Press 1 = Piano, 2 = Button Accordion", True, COLORS['hint_text']
        )
        self._center_text(hint, 90)
    
    def _draw_hinge_status(
        self, angle: float, velocity: float, available: bool
    ):
        """Draw hinge angle and status."""
        if available:
            angle_text = self.font_large.render(
                f"{int(angle)} deg", True, COLORS['accent']
            )
        else:
            angle_text = self.font_medium.render(
                "(Hinge sensor not available)", True, COLORS['inactive']
            )
        self._center_text(angle_text, 125)
        
        speed_text = self.font_small.render(
            f"Speed: {velocity:.1f} deg/s", True, COLORS['hint_text']
        )
        self._center_text(speed_text, 235)
    
    def _draw_volume_bar(self, volume: float):
        """Draw the bellows volume bar."""
        bar_x = 100
        bar_y = 180
        bar_width = 600
        bar_height = 40
        
        # Background
        pygame.draw.rect(
            self.screen,
            (40, 40, 60),
            (bar_x, bar_y, bar_width, bar_height),
            border_radius=5
        )
        
        # Fill
        fill_width = int(volume * bar_width)
        if fill_width > 0:
            r = int(100 + volume * 155)
            g = int(200 - volume * 50)
            pygame.draw.rect(
                self.screen,
                (r, g, 100),
                (bar_x, bar_y, fill_width, bar_height),
                border_radius=5
            )
        
        # Label
        vol_text = self.font_medium.render(
            f"BELLOWS: {int(volume * 100)}%", True, COLORS['text']
        )
        self._center_text(vol_text, bar_y + 5)
    
    def _draw_active_notes(self, active_notes: Set[int]):
        """Draw currently playing notes."""
        y = 275
        
        if active_notes:
            names = [
                f"{NOTE_NAMES[n % 12]}{n // 12 - 1}"
                for n in sorted(active_notes)
            ]
            # Limit display to 8 notes
            display_text = " ".join(names[:8])
            text = self.font_large.render(display_text, True, COLORS['active_note'])
        else:
            text = self.font_small.render(
                "Hold keys and move screen to play", True, COLORS['inactive']
            )
        
        self._center_text(text, y)
    
    def _draw_octave(self, octave: int):
        """Draw octave indicator."""
        text = self.font_small.render(
            f"Octave: C{octave}  (use [ ] to change)", True, COLORS['text']
        )
        self._center_text(text, 330)
        
        # Octave dots
        dot_y = 360
        center_x = WINDOW_WIDTH // 2
        total_dots = MAX_OCTAVE - MIN_OCTAVE + 1
        start_x = center_x - (total_dots * 20) // 2
        
        for i in range(total_dots):
            current_octave = MIN_OCTAVE + i
            color = COLORS['accent'] if current_octave == octave else COLORS['inactive']
            pygame.draw.circle(
                self.screen, color,
                (start_x + i * 20, dot_y), 6
            )
    
    def _draw_sustain(self, sustain: bool):
        """Draw sustain status."""
        color = COLORS['warning'] if sustain else COLORS['inactive']
        text = self.font_small.render(
            f"Sustain: {'ON' if sustain else 'OFF'} (Tab)", True, color
        )
        self._center_text(text, 390)
    
    def _draw_keyboard_hints(self, mode: int):
        """Draw keyboard hints based on current mode."""
        if mode == 0:
            hints = [
                "=== PIANO MODE ===",
                "White: A S D F G H J K L ;",
                "Black: W E   T Y U   O P",
            ]
        else:
            hints = [
                "=== BUTTON ACCORDION (B-System) ===",
                "Row 1: Q W E R T Y U I O P",
                "Row 2: A S D F G H J K L ;",
                "Row 3: Z X C V B N M , . /",
            ]
        
        y = 430
        for hint in hints:
            text = self.font_small.render(hint, True, COLORS['hint_text'])
            self._center_text(text, y)
            y += 24
    
    def _draw_footer(self):
        """Draw footer text."""
        footer = self.font_small.render(
            "Esc: Quit | Move screen = bellows!",
            True, (100, 100, 120)
        )
        self._center_text(footer, WINDOW_HEIGHT - 35)
    
    def _center_text(self, surface: pygame.Surface, y: int):
        """Helper to center text horizontally."""
        x = WINDOW_WIDTH // 2 - surface.get_width() // 2
        self.screen.blit(surface, (x, y))
