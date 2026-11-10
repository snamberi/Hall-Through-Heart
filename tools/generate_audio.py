#!/usr/bin/env python3
"""Synthesises the game's placeholder sound effects into assets/audio/.

Run from the project folder:  python3 tools/generate_audio.py
"""
import math
import os
import struct
import wave

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
RATE = 22050


def write(name, samples):
    os.makedirs(ROOT, exist_ok=True)
    with wave.open(os.path.join(ROOT, name), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples))


def level_up():
    notes = [523.25, 659.25, 783.99, 1046.5]  # rising C major arpeggio
    step, tail = 0.09, 0.6
    total = int((step * len(notes) + tail) * RATE)
    out = [0.0] * total
    for i, freq in enumerate(notes):
        start = int(i * step * RATE)
        for n in range(total - start):
            t = n / RATE
            envelope = min(t / 0.005, 1.0) * math.exp(-t * 5.0)
            tone = math.sin(2 * math.pi * freq * t) + 0.3 * math.sin(4 * math.pi * freq * t)
            out[start + n] += 0.28 * envelope * tone
    return out


if __name__ == "__main__":
    write("level_up.wav", level_up())
