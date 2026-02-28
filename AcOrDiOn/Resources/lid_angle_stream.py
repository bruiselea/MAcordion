#!/usr/bin/env python3
"""Background script to continuously output lid angle"""
import sys
import time
from pybooklid import read_lid_angle

# Flush output immediately
sys.stdout.reconfigure(line_buffering=True)

while True:
    try:
        angle = read_lid_angle()
        print(angle, flush=True)
        time.sleep(1.0/30.0)  # 30Hz update rate
    except Exception as e:
        print(f"ERROR:{e}", flush=True)
        time.sleep(0.1)
