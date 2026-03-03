"""
AcOrDiOn - Hinge Monitor
MacBookのヒンジ角度センサーを監視するモジュール
"""

import threading
import time
from typing import Callable, Optional

from .config import (
    HINGE_POLL_RATE, HINGE_HISTORY_SIZE,
    VELOCITY_SMOOTHING, VOLUME_SMOOTHING
)


class HingeMonitor:
    """Monitors MacBook hinge angle and calculates bellows volume.
    
    The hinge angle sensor is accessed via pybooklid library.
    Angular velocity (speed of lid movement) is mapped to volume,
    simulating how an accordion's bellows work.
    """
    
    def __init__(self):
        """Initialize the hinge monitor."""
        self.current_angle = 90.0
        self.angular_velocity = 0.0
        self.volume = 0.5
        
        self._angle_history = [90.0] * HINGE_HISTORY_SIZE
        self._running = False
        self._thread: Optional[threading.Thread] = None
        self._hinge_available = False
        self._read_lid_angle = None
        
        # Try to import pybooklid
        try:
            from pybooklid import read_lid_angle
            self._read_lid_angle = read_lid_angle
            self._hinge_available = True
        except ImportError:
            pass
    
    @property
    def is_available(self) -> bool:
        """Check if hinge sensor is available."""
        return self._hinge_available
    
    def start(self):
        """Start monitoring the hinge angle in a background thread."""
        if self._running or not self._hinge_available:
            return
            
        self._running = True
        self._thread = threading.Thread(target=self._monitor_loop, daemon=True)
        self._thread.start()
    
    def stop(self):
        """Stop monitoring."""
        self._running = False
        if self._thread:
            self._thread.join(timeout=1.0)
            self._thread = None
    
    def _monitor_loop(self):
        """Background monitoring loop."""
        poll_interval = 1.0 / HINGE_POLL_RATE
        
        while self._running:
            try:
                angle = self._read_lid_angle()
                self._update(angle)
            except Exception:
                pass
            
            time.sleep(poll_interval)
    
    def _update(self, raw_angle: float):
        """Process a new angle reading.
        
        Args:
            raw_angle: Raw angle reading from sensor
        """
        # Smooth the angle
        self._angle_history.pop(0)
        self._angle_history.append(raw_angle)
        smoothed = sum(self._angle_history) / len(self._angle_history)
        
        # Calculate angular velocity
        delta = abs(smoothed - self.current_angle)
        velocity = delta * 15  # Scale factor
        
        # Smooth velocity
        self.angular_velocity = (
            self.angular_velocity * VELOCITY_SMOOTHING +
            velocity * (1 - VELOCITY_SMOOTHING)
        )
        self.angular_velocity = min(50, self.angular_velocity)
        
        # Map velocity to volume (bellows effect)
        target_volume = self._velocity_to_volume(self.angular_velocity)
        
        # Smooth volume
        self.volume = (
            self.volume * VOLUME_SMOOTHING +
            target_volume * (1 - VOLUME_SMOOTHING)
        )
        self.volume = max(0.0, min(1.0, self.volume))
        
        self.current_angle = smoothed
    
    def _velocity_to_volume(self, velocity: float) -> float:
        """Map angular velocity to volume level.
        
        Args:
            velocity: Angular velocity in degrees/second
            
        Returns:
            Target volume (0.0 to 1.0)
        """
        if velocity < 0.5:
            return 0.05  # Almost silent when still
        elif velocity < 2:
            return 0.1 + (velocity - 0.5) * 0.25
        elif velocity < 8:
            return 0.45 + (velocity - 2) * 0.08
        else:
            return 0.95  # Maximum volume
