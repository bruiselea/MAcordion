#!/usr/bin/env python3
"""
AcOrDiOn - MacBook Accordion App
Python + Pygame with Improved Accordion Sound
"""

import pygame
import threading
import time
import math
import numpy as np

try:
    from pybooklid import read_lid_angle
    HINGE_AVAILABLE = True
    print("Hinge sensor: AVAILABLE")
except ImportError:
    HINGE_AVAILABLE = False
    print("Hinge sensor: NOT AVAILABLE")

pygame.init()
pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=256)

WINDOW_WIDTH = 750
WINDOW_HEIGHT = 600
FPS = 60

BG_COLOR = (26, 26, 46)
TEXT_COLOR = (255, 255, 255)
ACCENT_COLOR = (100, 200, 255)
ACTIVE_COLOR = (80, 200, 120)
WARNING_COLOR = (255, 150, 50)
MODE_COLOR = (255, 100, 100)

PIANO_KEY_MAP = {
    pygame.K_a: 0, pygame.K_s: 2, pygame.K_d: 4, pygame.K_f: 5,
    pygame.K_g: 7, pygame.K_h: 9, pygame.K_j: 11, pygame.K_k: 12,
    pygame.K_l: 14, pygame.K_SEMICOLON: 16,
    pygame.K_w: 1, pygame.K_e: 3, pygame.K_t: 6, pygame.K_y: 8,
    pygame.K_u: 10, pygame.K_o: 13, pygame.K_p: 15,
}

BUTTON_KEY_MAP = {
    pygame.K_q: 0, pygame.K_w: 1, pygame.K_e: 2, pygame.K_r: 3,
    pygame.K_t: 4, pygame.K_y: 5, pygame.K_u: 6, pygame.K_i: 7,
    pygame.K_o: 8, pygame.K_p: 9,
    pygame.K_a: 3, pygame.K_s: 4, pygame.K_d: 5, pygame.K_f: 6,
    pygame.K_g: 7, pygame.K_h: 8, pygame.K_j: 9, pygame.K_k: 10,
    pygame.K_l: 11, pygame.K_SEMICOLON: 12,
    pygame.K_z: 6, pygame.K_x: 7, pygame.K_c: 8, pygame.K_v: 9,
    pygame.K_b: 10, pygame.K_n: 11, pygame.K_m: 12, pygame.K_COMMA: 13,
    pygame.K_PERIOD: 14, pygame.K_SLASH: 15,
}

NOTE_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']


def generate_accordion_tone(frequency):
    """Generate realistic accordion reed sound"""
    sample_rate = 44100
    duration = 4.0
    n_samples = int(sample_rate * duration)
    t = np.linspace(0, duration, n_samples, False)
    
    # Accordion reeds produce a "sawtooth-like" wave (bright, buzzy sound)
    # We'll use additive synthesis with many harmonics
    
    wave = np.zeros(n_samples)
    
    # Reed 1 - Main fundamental with sawtooth-like harmonics
    for h in range(1, 12):  # More harmonics for buzzy reed sound
        # Each harmonic decreases in amplitude
        amp = 0.5 / h
        wave += amp * np.sin(2 * np.pi * frequency * h * t)
    
    # Reed 2 - Slightly sharp (musette tuning) - creates the "wet" tremolo
    detune_sharp = 1.006  # ~10 cents sharp
    for h in range(1, 8):
        amp = 0.4 / h
        wave += amp * np.sin(2 * np.pi * frequency * detune_sharp * h * t)
    
    # Reed 3 - Slightly flat
    detune_flat = 0.994  # ~10 cents flat
    for h in range(1, 8):
        amp = 0.4 / h
        wave += amp * np.sin(2 * np.pi * frequency * detune_flat * h * t)
    
    # Add some "air"/noise characteristic of accordion bellows
    noise = np.random.randn(n_samples) * 0.02
    noise_filtered = np.convolve(noise, np.ones(100)/100, mode='same')  # Low-pass filter
    wave += noise_filtered
    
    # Add subtle amplitude modulation (tremolo from beating reeds)
    tremolo = 1 + 0.05 * np.sin(2 * np.pi * 4 * t)  # 4Hz tremolo
    wave = wave * tremolo
    
    # Quick attack (reed response)
    attack = int(0.008 * sample_rate)  # 8ms attack
    wave[:attack] *= np.linspace(0, 1, attack)
    
    # Normalize
    wave = wave / np.max(np.abs(wave)) * 0.45
    
    # Convert to 16-bit stereo
    wave = (wave * 32767).astype(np.int16)
    stereo = np.column_stack((wave, wave))
    
    return pygame.sndarray.make_sound(stereo)


class AccordionApp:
    def __init__(self):
        self.screen = pygame.display.set_mode((WINDOW_WIDTH, WINDOW_HEIGHT))
        pygame.display.set_caption("AcOrDiOn - MacBook Accordion")
        self.clock = pygame.time.Clock()
        
        self.font = pygame.font.SysFont("Arial", 42)
        self.medium_font = pygame.font.SysFont("Arial", 28)
        self.small_font = pygame.font.SysFont("Arial", 20)
        
        self.sounds = {}
        self.channels = {}
        
        print("Generating realistic accordion sounds (this may take a moment)...")
        self.setup_sounds()
        
        self.mode = 0
        self.mode_names = ["Piano Mode", "Button Accordion (B-System)"]
        
        self.octave = 4
        self.active_notes = set()
        self.sustain = False
        self.running = True
        
        self.current_angle = 90.0
        self.angle_history = [90.0] * 3  # Reduced from 10 to 3
        self.angular_velocity = 0.0
        self.volume = 0.5
        self.last_motion_time = time.time()
        self.idle_timeout = 0.6  # seconds without motion before we consider idle
        
        pygame.mixer.set_num_channels(32)
        
        if HINGE_AVAILABLE:
            self.hinge_thread = threading.Thread(target=self.monitor_hinge, daemon=True)
            self.hinge_thread.start()
    
    def setup_sounds(self):
        for octave in range(2, 7):
            for i in range(12):
                midi_note = octave * 12 + i
                frequency = 440.0 * (2.0 ** ((midi_note - 69) / 12.0))
                self.sounds[midi_note] = generate_accordion_tone(frequency)
                # Progress indicator
                if midi_note % 12 == 0:
                    print(f"  Generating octave {octave}...")
        
        print(f"Generated {len(self.sounds)} accordion sounds!")
    
    def get_key_map(self):
        return BUTTON_KEY_MAP if self.mode == 1 else PIANO_KEY_MAP
    
    def monitor_hinge(self):
        while self.running:
            try:
                angle = read_lid_angle()
                
                # Lighter smoothing on angle (3 samples instead of 10)
                self.angle_history.pop(0)
                self.angle_history.append(angle)
                smoothed = sum(self.angle_history) / len(self.angle_history)
                
                delta = abs(smoothed - self.current_angle)
                velocity = delta * 15  # Increased sensitivity
                
                # Deadzone and hysteresis for tiny motions
                if velocity < 0.25:
                    velocity = 0.0
                
                # Lighter velocity smoothing (0.5/0.5 instead of 0.85/0.15)
                self.angular_velocity = self.angular_velocity * 0.5 + velocity * 0.5
                self.angular_velocity = min(50, self.angular_velocity)

                if self.angular_velocity > 0.35:
                    self.last_motion_time = time.time()
                
                # Map velocity to target volume with softer curve
                if self.angular_velocity <= 0.35:
                    target = 0.0
                elif self.angular_velocity < 2.0:
                    # gentle ramp up from 0 to ~0.35
                    t = (self.angular_velocity - 0.35) / (2.0 - 0.35)
                    target = 0.35 * t
                elif self.angular_velocity < 8.0:
                    # mid range up to ~0.85
                    t = (self.angular_velocity - 2.0) / (8.0 - 2.0)
                    target = 0.35 + 0.5 * t
                else:
                    target = 1.0
                
                # Volume smoothing with asymmetric response (faster attack, slower release)
                if target > self.volume:
                    alpha = 0.6  # attack
                else:
                    alpha = 0.25  # release
                self.volume = (1 - alpha) * self.volume + alpha * target
                self.volume = max(0.0, min(1.0, self.volume))
                
                self.current_angle = smoothed
            except:
                pass
            
            # Idle handling: if no meaningful motion for a while, decay volume to 0
            if time.time() - self.last_motion_time > self.idle_timeout:
                # slower release to zero when idle
                self.volume = max(0.0, self.volume * 0.90)
                # also slowly bleed angular velocity to zero
                self.angular_velocity = max(0.0, self.angular_velocity * 0.85)
            
            time.sleep(0.015)  # Faster polling: 66Hz instead of 33Hz
    
    def update_playing_volumes(self):
        """Update volume for all playing notes in real-time"""
        actual_vol = max(0.0, self.volume)
        very_quiet = actual_vol < 0.01

        # Update each channel's volume
        for note, channel in list(self.channels.items()):
            if channel.get_busy():
                # Use both sound volume and channel volume for redundancy
                self.sounds[note].set_volume(actual_vol) # Set sound volume
                channel.set_volume(actual_vol, actual_vol) # Set channel volume
                # Force-stop channels when effectively silent to avoid lingering
                if very_quiet:
                    try:
                        channel.stop()
                    except Exception:
                        pass
                    if note in self.channels:
                        try:
                            del self.channels[note]
                        except KeyError:
                            pass
            else:
                # Channel finished playing; cleanup mapping if exists
                if note in self.channels:
                    try:
                        del self.channels[note]
                    except KeyError:
                        pass

        # Secondary sweep to ensure no stale channels remain
        for note in list(self.channels.keys()):
            ch = self.channels.get(note)
            if ch and not ch.get_busy():
                try:
                    del self.channels[note]
                except KeyError:
                    pass
    
    def note_on(self, note_offset):
        midi_note = 60 + (self.octave - 4) * 12 + note_offset
        midi_note = max(24, min(96, midi_note))
        
        if midi_note not in self.active_notes:
            self.active_notes.add(midi_note)
            
            if midi_note in self.sounds:
                channel = pygame.mixer.find_channel(True)
                if channel:
                    vol = max(0.0, self.volume)
                    channel.set_volume(vol, vol)
                    channel.play(self.sounds[midi_note], loops=-1)
                    self.channels[midi_note] = channel
            
            print(f"Note ON: {NOTE_NAMES[midi_note % 12]}{midi_note // 12 - 1}")
    
    def note_off(self, note_offset):
        midi_note = 60 + (self.octave - 4) * 12 + note_offset
        midi_note = max(24, min(96, midi_note))
        
        if midi_note in self.active_notes and not self.sustain:
            self.active_notes.discard(midi_note)
            
            if midi_note in self.channels:
                self.channels[midi_note].fadeout(100)
                del self.channels[midi_note]
    
    def all_notes_off(self):
        for note, channel in list(self.channels.items()):
            channel.fadeout(80)
        self.channels.clear()
        self.active_notes.clear()
    
    def handle_events(self):
        key_map = self.get_key_map()
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.running = False
            
            elif event.type == pygame.KEYDOWN:
                key = event.key
                
                if key == pygame.K_1:
                    self.mode = 0
                    self.all_notes_off()
                elif key == pygame.K_2:
                    self.mode = 1
                    self.all_notes_off()
                elif key == pygame.K_MINUS or key == pygame.K_LEFTBRACKET:
                    self.octave = max(2, self.octave - 1)
                elif key == pygame.K_EQUALS or key == pygame.K_RIGHTBRACKET:
                    self.octave = min(6, self.octave + 1)
                elif key == pygame.K_TAB:
                    self.sustain = not self.sustain
                    # When turning sustain OFF, immediately stop any channels for notes not currently active
                    if not self.sustain:
                        for note, channel in list(self.channels.items()):
                            if note not in self.active_notes:
                                try:
                                    channel.stop()
                                except Exception:
                                    pass
                                try:
                                    del self.channels[note]
                                except KeyError:
                                    pass
                    if not self.sustain:
                        self.all_notes_off()
                elif key == pygame.K_ESCAPE:
                    self.running = False
                elif key in key_map:
                    self.note_on(key_map[key])
            
            elif event.type == pygame.KEYUP:
                if event.key in key_map:
                    self.note_off(key_map[event.key])
    
    def draw(self):
        self.screen.fill(BG_COLOR)
        
        title = self.font.render("AcOrDiOn", True, TEXT_COLOR)
        self.screen.blit(title, (WINDOW_WIDTH // 2 - title.get_width() // 2, 15))
        
        mode_text = self.medium_font.render(f"Mode: {self.mode_names[self.mode]}", True, MODE_COLOR)
        self.screen.blit(mode_text, (WINDOW_WIDTH // 2 - mode_text.get_width() // 2, 60))
        
        mode_hint = self.small_font.render("Press 1 = Piano, 2 = Button Accordion", True, (150, 150, 150))
        self.screen.blit(mode_hint, (WINDOW_WIDTH // 2 - mode_hint.get_width() // 2, 90))
        
        angle_text = self.font.render(f"{int(self.current_angle)} deg", True, ACCENT_COLOR)
        self.screen.blit(angle_text, (WINDOW_WIDTH // 2 - angle_text.get_width() // 2, 125))
        
        bar_x, bar_y = 100, 180
        bar_width, bar_height = 550, 35
        
        pygame.draw.rect(self.screen, (40, 40, 60), (bar_x, bar_y, bar_width, bar_height), border_radius=5)
        fill = int(self.volume * bar_width)
        if fill > 0:
            r = int(100 + self.volume * 155)
            g = int(200 - self.volume * 50)
            pygame.draw.rect(self.screen, (r, g, 100), (bar_x, bar_y, fill, bar_height), border_radius=5)
        
        vol_text = self.medium_font.render(f"BELLOWS: {int(self.volume * 100)}%", True, TEXT_COLOR)
        self.screen.blit(vol_text, (bar_x + bar_width // 2 - vol_text.get_width() // 2, bar_y + 3))
        
        speed_text = self.small_font.render(f"Speed: {self.angular_velocity:.1f} deg/s", True, (150, 150, 180))
        self.screen.blit(speed_text, (WINDOW_WIDTH // 2 - speed_text.get_width() // 2, bar_y + bar_height + 5))
        
        notes_y = 260
        if self.active_notes:
            names = [f"{NOTE_NAMES[n % 12]}{n // 12 - 1}" for n in sorted(self.active_notes)]
            notes_text = self.font.render(" ".join(names[:8]), True, ACTIVE_COLOR)
        else:
            notes_text = self.small_font.render("Hold keys and move screen to play", True, (100, 100, 100))
        self.screen.blit(notes_text, (WINDOW_WIDTH // 2 - notes_text.get_width() // 2, notes_y))
        
        oct_text = self.small_font.render(f"Octave: C{self.octave}  (use [ ] to change)", True, TEXT_COLOR)
        self.screen.blit(oct_text, (WINDOW_WIDTH // 2 - oct_text.get_width() // 2, 310))
        
        sus_color = WARNING_COLOR if self.sustain else (80, 80, 80)
        sus_text = self.small_font.render(f"Sustain: {'ON' if self.sustain else 'OFF'} (Tab)", True, sus_color)
        self.screen.blit(sus_text, (WINDOW_WIDTH // 2 - sus_text.get_width() // 2, 340))
        
        if self.mode == 0:
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
        
        y = 390
        for hint in hints:
            h = self.small_font.render(hint, True, (140, 140, 160))
            self.screen.blit(h, (WINDOW_WIDTH // 2 - h.get_width() // 2, y))
            y += 24
        
        footer = self.small_font.render("Esc: Quit | Move screen = bellows!", True, (100, 100, 120))
        self.screen.blit(footer, (WINDOW_WIDTH // 2 - footer.get_width() // 2, WINDOW_HEIGHT - 35))
        
        pygame.display.flip()
    
    def run(self):
        print("\n" + "="*50)
        print("AcOrDiOn - MacBook Accordion")
        print("="*50)
        print("\nModes: 1=Piano, 2=Button Accordion")
        print("Move the screen like accordion bellows!\n")
        
        while self.running:
            self.handle_events()
            self.update_playing_volumes()
            # Auto stop notes when effectively silent and idle
            if self.volume < 0.01 and self.angular_velocity < 0.2 and self.active_notes and (time.time() - self.last_motion_time > self.idle_timeout):
                self.all_notes_off()
            # Hard cleanup for any lingering channels when silent and idle
            if self.volume < 0.01 and self.angular_velocity < 0.2 and (time.time() - self.last_motion_time > self.idle_timeout):
                for note, ch in list(self.channels.items()):
                    try:
                        ch.stop()
                    except Exception:
                        pass
                    try:
                        del self.channels[note]
                    except KeyError:
                        pass
            self.draw()
            self.clock.tick(FPS)
        
        self.cleanup()
    
    def cleanup(self):
        self.all_notes_off()
        pygame.mixer.quit()
        pygame.quit()


if __name__ == "__main__":
    app = AccordionApp()
    app.run()
