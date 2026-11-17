#!/usr/bin/env python3
"""Synthesises every creature's own sounds into assets/audio/creatures/.

Each animal and monster gets four: <id>_idle, <id>_hurt, <id>_death and
<id>_step. They are built from a voice profile per creature (its family,
pitch, the shape of its mouth, how rough it is, what its feet are like),
and each creature's noise is seeded by its own name, so no two sound the
same even within a family.

Run from the project folder:  python3 tools/generate_creature_audio.py
"""
import os
import struct
import wave
import zlib

import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "creatures")
RATE = 22050


def write(name, samples):
    os.makedirs(ROOT, exist_ok=True)
    samples = np.asarray(samples, dtype=np.float64)
    peak = np.max(np.abs(samples)) if len(samples) else 1.0
    if peak > 0:
        samples = samples / peak * 0.85
    # A few milliseconds of fade at each end so nothing clicks.
    fade = min(len(samples) // 4, int(0.004 * RATE))
    if fade > 0:
        ramp = np.linspace(0.0, 1.0, fade)
        samples[:fade] *= ramp
        samples[-fade:] *= ramp[::-1]
    data = (np.clip(samples, -1, 1) * 32000).astype("<i2").tobytes()
    with wave.open(os.path.join(ROOT, name + ".wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data)


def times(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def envelope(seconds, attack=0.01, release=0.2, sustain=1.0):
    t = times(seconds)
    env = np.minimum(t / max(attack, 1e-4), 1.0)
    tail = np.clip((seconds - t) / max(release, 1e-4), 0.0, 1.0)
    return env * np.minimum(tail, 1.0) * sustain


def shape_spectrum(signal, formants, width=1.0):
    """Gives a sound a mouth: boosts bands around each formant, softly."""
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(len(signal), 1.0 / RATE)
    gain = np.full_like(freqs, 0.06)
    for centre, strength in formants:
        bandwidth = max(centre * 0.18 * width, 60.0)
        gain += strength * np.exp(-0.5 * ((freqs - centre) / bandwidth) ** 2)
    return np.fft.irfft(spectrum * gain, len(signal))


def band(signal, low, high):
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(len(signal), 1.0 / RATE)
    spectrum[(freqs < low) | (freqs > high)] *= 0.02
    return np.fft.irfft(spectrum, len(signal))


def voice(rng, seconds, start, end, formants, rough=0.2, vibrato=(0.0, 0.0), breath=0.15, harmonics=14, bend=1.0):
    """A throat: a buzz that slides from `start` to `end` Hz (bent by
    `bend`), shaped by formants, with grit and breath."""
    t = times(seconds)
    share = (t / seconds) ** bend
    pitch = start + (end - start) * share
    if vibrato[1] > 0:
        pitch = pitch * (1.0 + vibrato[1] * np.sin(2 * np.pi * vibrato[0] * t))
    pitch = pitch * (1.0 + 0.02 * rng.standard_normal(len(t)).cumsum() / np.sqrt(np.arange(1, len(t) + 1)))
    phase = 2 * np.pi * np.cumsum(pitch) / RATE
    buzz = np.zeros_like(t)
    for h in range(1, harmonics + 1):
        buzz += np.sin(h * phase + rng.uniform(0, 6.28)) / h ** 1.1
    if rough > 0:
        grit = 1.0 + rough * band(rng.standard_normal(len(t)), 20, 90) * 6.0
        buzz *= np.clip(grit, 0.0, 2.5)
    air = rng.standard_normal(len(t)) * breath
    return shape_spectrum(buzz + air, formants)


def noise_burst(rng, seconds, low, high, attack=0.002, release=None):
    sound = band(rng.standard_normal(int(seconds * RATE)), low, high)
    return sound * envelope(seconds, attack, release if release else seconds * 0.8)


def thud(rng, seconds, pitch, drop=0.6, grit=0.2):
    t = times(seconds)
    f = pitch * (1.0 - drop * t / seconds)
    body = np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 18.0 / seconds * 0.3)
    return mix(body * envelope(seconds, 0.002, seconds * 0.9), grit * noise_burst(rng, seconds, 80, 900, release=seconds * 0.4))


def clicks(rng, seconds, count, low, high, spread=1.0):
    out = np.zeros(int(seconds * RATE))
    for i in range(count):
        at = int(min(seconds * 0.95, (i + rng.uniform(0, spread)) * seconds / count) * RATE)
        click = noise_burst(rng, 0.012, low, high, attack=0.0005, release=0.01) * rng.uniform(0.6, 1.0)
        end = min(len(out), at + len(click))
        out[at:end] += click[:end - at]
    return out


def chirp(rng, seconds, start, end, wobble=0.0):
    t = times(seconds)
    f = start + (end - start) * t / seconds
    if wobble:
        f *= 1.0 + wobble * np.sin(2 * np.pi * 30 * t)
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * envelope(seconds, 0.004, seconds * 0.7)


def bubbles(rng, seconds, count, low, high):
    out = np.zeros(int(seconds * RATE))
    for i in range(count):
        at = int(rng.uniform(0, seconds * 0.8) * RATE)
        size = rng.uniform(0.03, 0.08)
        blip = chirp(rng, size, rng.uniform(low, high), rng.uniform(high, high * 1.8))
        end = min(len(out), at + len(blip))
        out[at:end] += blip[:end - at] * rng.uniform(0.4, 1.0)
    return out


def crackle(rng, seconds, density=60):
    out = np.zeros(int(seconds * RATE))
    for _ in range(int(density * seconds)):
        at = rng.integers(0, max(len(out) - 300, 1))
        pop = noise_burst(rng, 0.006, 1500, 7000, attack=0.0003, release=0.005) * rng.uniform(0.3, 1.0)
        out[at:at + len(pop)] += pop
    return out


def echo(signal, delay=0.07, decay=0.45, taps=3):
    out = np.copy(signal)
    shift = int(delay * RATE)
    padded = np.concatenate([out, np.zeros(shift * taps)])
    for i in range(1, taps + 1):
        padded[shift * i:shift * i + len(signal)] += signal * decay ** i
    return padded


def stretch(signal, factor):
    """Plays a sound `factor` times faster (higher and shorter) or slower."""
    length = max(int(len(signal) / factor), 2)
    return np.interp(np.linspace(0, len(signal) - 1, length), np.arange(len(signal)), signal)


def mix(*parts):
    length = max(len(p) for p in parts)
    out = np.zeros(length)
    for p in parts:
        out[:len(p)] += p
    return out


def concat(*parts, gap=0.0):
    pieces = []
    silence = np.zeros(int(gap * RATE))
    for p in parts:
        pieces += [p, silence]
    return np.concatenate(pieces[:-1]) if pieces else np.zeros(1)


# --- footsteps, by kind of foot

def step_sound(rng, foot, weight):
    if foot == "hoof":
        a = thud(rng, 0.06, 900 * rng.uniform(0.8, 1.2), 0.5, 0.5)
        b = thud(rng, 0.05, 1100 * rng.uniform(0.8, 1.2), 0.5, 0.4)
        return concat(a, b * 0.7, gap=0.05)
    if foot == "paw":
        return mix(noise_burst(rng, 0.08, 150, 1200 * weight, release=0.07), 0.5 * thud(rng, 0.07, 120, 0.3, 0.0))
    if foot == "heavy":
        return mix(thud(rng, 0.28, 55 / weight, 0.5, 0.6), 0.4 * noise_burst(rng, 0.25, 60, 600, release=0.2))
    if foot == "skitter":
        return clicks(rng, 0.12, 5, 2500, 7000)
    if foot == "squish":
        return mix(noise_burst(rng, 0.14, 100, 700, release=0.12), 0.4 * chirp(rng, 0.1, 300, 120))
    if foot == "wing":
        flap = noise_burst(rng, 0.09, 200, 1800, attack=0.02, release=0.06)
        return concat(flap, flap * 0.7, gap=0.03)
    if foot == "drift":
        return noise_burst(rng, 0.22, 300, 1500, attack=0.08, release=0.12) * 0.6
    if foot == "shuffle":
        return noise_burst(rng, 0.2, 120, 1600, attack=0.05, release=0.12) * 0.8
    if foot == "clank":
        ring = np.sin(2 * np.pi * 1900 * times(0.12)) * np.exp(-times(0.12) * 35)
        return mix(thud(rng, 0.1, 140, 0.4, 0.3), 0.35 * ring, 0.4 * clicks(rng, 0.1, 2, 2000, 6000))
    if foot == "creak":
        return mix(thud(rng, 0.2, 80, 0.3, 0.4), 0.5 * noise_burst(rng, 0.18, 400, 2500, release=0.15))
    if foot == "hop":
        return thud(rng, 0.06, 260 * rng.uniform(0.9, 1.2), 0.4, 0.3)
    if foot == "peck":
        return clicks(rng, 0.08, 2, 1500, 4500)
    return noise_burst(rng, 0.08, 150, 2000, release=0.06)


# --- voices, by family

def calls(rng, family, p):
    """idle, hurt and death for one creature."""
    pitch, f1, f2, rough = p["pitch"], p.get("f1", 600), p.get("f2", 1500), p.get("rough", 0.2)
    formants = [(f1, 1.0), (f2, 0.7), (p.get("f3", f2 * 1.9), 0.3)]
    vib = p.get("vibrato", (0.0, 0.0))
    if family == "groan":
        idle = voice(rng, 0.9, pitch * 1.05, pitch * 0.92, formants, rough, (5, 0.02), 0.25, bend=0.6) * envelope(0.9, 0.15, 0.4)
        hurt = voice(rng, 0.3, pitch * 1.7, pitch * 1.2, formants, rough + 0.2, breath=0.3) * envelope(0.3, 0.01, 0.2)
        death = voice(rng, 1.4, pitch * 1.2, pitch * 0.55, formants, rough + 0.1, (4, 0.03), 0.35, bend=0.7) * envelope(1.4, 0.05, 0.9)
    elif family == "canine":
        growl = voice(rng, 0.7, pitch * 0.5, pitch * 0.48, formants, 0.9, breath=0.2) * envelope(0.7, 0.08, 0.3)
        bark = voice(rng, 0.14, pitch * 1.3, pitch * 0.9, formants, 0.3, breath=0.3) * envelope(0.14, 0.005, 0.1)
        idle = concat(bark, bark * 0.8, gap=0.12) if p.get("barks", True) else growl
        hurt = voice(rng, 0.25, pitch * 3.0, pitch * 2.0, formants, 0.1, breath=0.1) * envelope(0.25, 0.005, 0.18)
        death = voice(rng, 0.9, pitch * 2.4, pitch * 0.9, formants, 0.15, (7, 0.04), 0.15) * envelope(0.9, 0.01, 0.7)
        if p.get("howl"):
            idle = voice(rng, 1.4, pitch * 1.6, pitch * 2.2, formants, 0.05, (5, 0.02), 0.1, bend=0.5) * envelope(1.4, 0.3, 0.6)
    elif family == "bleat":
        idle = voice(rng, 0.7, pitch, pitch * 0.95, formants, rough, vib if vib[1] else (9, 0.06), 0.15) * envelope(0.7, 0.04, 0.3)
        hurt = voice(rng, 0.25, pitch * 1.5, pitch * 1.3, formants, rough + 0.1, (12, 0.08), 0.2) * envelope(0.25, 0.01, 0.15)
        death = voice(rng, 1.0, pitch * 1.2, pitch * 0.6, formants, rough, (8, 0.07), 0.2) * envelope(1.0, 0.02, 0.7)
    elif family == "moo":
        idle = voice(rng, 1.3, pitch * 0.95, pitch * 1.05, formants, rough, (3, 0.01), 0.1, bend=1.5) * envelope(1.3, 0.15, 0.5)
        hurt = voice(rng, 0.35, pitch * 1.6, pitch * 1.3, formants, rough + 0.2) * envelope(0.35, 0.01, 0.2)
        death = voice(rng, 1.4, pitch * 1.1, pitch * 0.6, formants, rough, (4, 0.03), 0.2) * envelope(1.4, 0.05, 1.0)
    elif family == "oink":
        snort = mix(voice(rng, 0.16, pitch, pitch * 0.9, formants, 0.8, breath=0.4), noise_burst(rng, 0.16, 200, 1500) * 0.5) * envelope(0.16, 0.005, 0.1)
        idle = concat(snort, snort * 0.8, snort * 0.6, gap=0.06)
        hurt = voice(rng, 0.3, pitch * 3.0, pitch * 2.2, formants, 0.4, breath=0.3) * envelope(0.3, 0.005, 0.2)
        death = voice(rng, 0.8, pitch * 2.6, pitch * 0.8, formants, 0.5, breath=0.3) * envelope(0.8, 0.01, 0.6)
    elif family == "roar":
        idle = voice(rng, 1.0, pitch * 0.8, pitch * 0.75, formants, rough + 0.6, breath=0.4) * envelope(1.0, 0.2, 0.4)
        hurt = voice(rng, 0.35, pitch * 1.6, pitch * 1.1, formants, rough + 0.5, breath=0.4) * envelope(0.35, 0.01, 0.2)
        death = voice(rng, 1.5, pitch * 1.3, pitch * 0.5, formants, rough + 0.4, (4, 0.03), 0.5, bend=0.6) * envelope(1.5, 0.02, 1.1)
    elif family == "chirp":
        notes = [chirp(rng, rng.uniform(0.05, 0.1), pitch * rng.uniform(0.9, 1.1), pitch * rng.uniform(1.2, 1.6), 0.02) for _ in range(p.get("notes", 3))]
        idle = concat(*notes, gap=0.05)
        hurt = mix(chirp(rng, 0.15, pitch * 2.0, pitch * 1.2, 0.08), 0.3 * noise_burst(rng, 0.15, 2000, 7000))
        death = concat(chirp(rng, 0.2, pitch * 1.6, pitch * 0.6, 0.05), chirp(rng, 0.25, pitch * 1.0, pitch * 0.4, 0.05) * 0.6, gap=0.05)
    elif family == "cluck":
        cluck = voice(rng, 0.07, pitch, pitch * 0.8, formants, 0.2, breath=0.1) * envelope(0.07, 0.003, 0.05)
        idle = concat(*[cluck * rng.uniform(0.6, 1.0) for _ in range(4)], gap=0.07)
        hurt = voice(rng, 0.3, pitch * 1.8, pitch * 2.2, formants, 0.3, (14, 0.08), 0.3) * envelope(0.3, 0.005, 0.2)
        death = voice(rng, 0.6, pitch * 2.0, pitch * 0.8, formants, 0.3, (10, 0.06), 0.3) * envelope(0.6, 0.005, 0.5)
    elif family == "squeak":
        idle = concat(chirp(rng, 0.06, pitch, pitch * 1.3), chirp(rng, 0.05, pitch * 1.1, pitch * 1.4) * 0.7, gap=0.08)
        hurt = chirp(rng, 0.14, pitch * 1.8, pitch * 2.4, 0.05)
        death = chirp(rng, 0.4, pitch * 1.6, pitch * 0.6, 0.04)
    elif family == "slime":
        idle = bubbles(rng, 0.7, 6, pitch, pitch * 2.0)
        hurt = mix(noise_burst(rng, 0.2, 100, 900, release=0.18), 0.6 * chirp(rng, 0.18, pitch * 2, pitch * 0.8))
        death = mix(noise_burst(rng, 0.5, 60, 700, release=0.45), bubbles(rng, 0.8, 10, pitch * 0.8, pitch * 2.2) * 0.6)
        if p.get("fire"):
            idle = mix(idle, crackle(rng, 0.7, 40) * 0.5)
            death = mix(death, crackle(rng, 0.8, 80) * 0.6)
    elif family == "rock":
        idle = mix(voice(rng, 1.0, pitch, pitch * 0.9, formants, rough + 0.6, breath=0.5) * envelope(1.0, 0.3, 0.4), 0.3 * clicks(rng, 1.0, 6, 300, 2500))
        hurt = mix(noise_burst(rng, 0.25, 200, 4000, release=0.2), 0.5 * thud(rng, 0.25, 90, 0.5, 0.3))
        death = mix(clicks(rng, 1.2, 18, 200, 3500, 2.0) * 0.8, thud(rng, 1.0, 60, 0.6, 0.8), voice(rng, 1.2, pitch * 1.1, pitch * 0.5, formants, 0.9, breath=0.4) * envelope(1.2, 0.02, 0.9) * 0.6)
    elif family == "insect":
        chitter = clicks(rng, 0.4, int(p.get("clicks", 10)), pitch, pitch * 3)
        idle = mix(chitter, 0.4 * noise_burst(rng, 0.4, 3000, 8000, attack=0.1, release=0.2))
        hurt = mix(clicks(rng, 0.2, 8, pitch * 1.5, pitch * 4), 0.6 * noise_burst(rng, 0.2, 3000, 9000))
        death = mix(clicks(rng, 0.9, 14, pitch * 0.5, pitch * 2, 3.0), 0.5 * noise_burst(rng, 0.8, 2000, 8000, release=0.7))
    elif family == "hiss":
        low = pitch * 4.0
        idle = noise_burst(rng, 0.6, low, low * 3.5, attack=0.1, release=0.3) * (1 + 0.3 * np.sin(2 * np.pi * (pitch / 40.0) * times(0.6)))
        hurt = mix(noise_burst(rng, 0.2, low * 0.8, low * 3.5), 0.5 * clicks(rng, 0.2, 3, pitch * 2.5, pitch * 7))
        death = noise_burst(rng, 0.9, low * 0.6, low * 3.0, attack=0.02, release=0.8)
    elif family == "croak":
        pulse = voice(rng, 0.28, pitch, pitch * 0.95, formants, 0.6, breath=0.1) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 22 * times(0.28))))
        idle = concat(pulse, pulse * 0.8, gap=0.15)
        hurt = voice(rng, 0.18, pitch * 2.2, pitch * 1.6, formants, 0.3) * envelope(0.18, 0.005, 0.12)
        death = voice(rng, 0.7, pitch * 1.6, pitch * 0.6, formants, 0.6) * envelope(0.7, 0.01, 0.5)
    elif family == "spirit":
        idle = echo(voice(rng, 1.2, pitch, pitch * 1.15, formants, 0.02, (5, 0.03), 0.4, harmonics=4, bend=0.7) * envelope(1.2, 0.3, 0.6), 0.09, 0.5)
        hurt = echo(mix(chirp(rng, 0.3, pitch * 2.0, pitch * 1.3, 0.06), 0.4 * noise_burst(rng, 0.3, 1500, 6000)), 0.06, 0.4)
        death = echo(voice(rng, 1.4, pitch * 1.6, pitch * 0.4, formants, 0.02, (6, 0.05), 0.6, harmonics=4) * envelope(1.4, 0.05, 1.1), 0.1, 0.55, 4)
        if p.get("fire"):
            idle = mix(idle, crackle(rng, len(idle) / RATE, 50) * 0.5)
            death = mix(death, crackle(rng, len(death) / RATE, 90) * 0.6)
        if p.get("warp"):
            ring = np.sin(2 * np.pi * p["warp"] * times(len(idle) / RATE))
            idle = idle * (0.6 + 0.4 * ring)
    elif family == "wood":
        creak = voice(rng, 0.9, pitch, pitch * 1.3, formants, 0.7, (2, 0.04), 0.1, harmonics=8, bend=2.0) * envelope(0.9, 0.2, 0.4)
        idle = mix(creak, 0.4 * noise_burst(rng, 0.9, 800, 5000, attack=0.2, release=0.4))
        hurt = mix(noise_burst(rng, 0.25, 300, 5000), 0.5 * thud(rng, 0.2, 110, 0.4, 0.3))
        death = mix(voice(rng, 1.4, pitch * 1.4, pitch * 0.6, formants, 0.8, breath=0.2, harmonics=8) * envelope(1.4, 0.02, 1.0), clicks(rng, 1.3, 10, 400, 3000, 2.0) * 0.6)
        if p.get("spores"):
            idle = mix(idle, 0.5 * noise_burst(rng, 0.4, 1500, 6000, attack=0.02, release=0.35))
    elif family == "grunt":
        grunt = voice(rng, 0.22, pitch * 1.1, pitch * 0.9, formants, rough, breath=0.3) * envelope(0.22, 0.01, 0.15)
        idle = concat(grunt, grunt * 0.7, gap=0.25) if not p.get("chant") else voice(rng, 1.2, pitch, pitch, formants, 0.1, (4, 0.02), 0.2) * envelope(1.2, 0.2, 0.4)
        hurt = voice(rng, 0.25, pitch * 1.8, pitch * 1.4, formants, rough + 0.2, breath=0.4) * envelope(0.25, 0.005, 0.18)
        death = voice(rng, 1.0, pitch * 1.6, pitch * 0.6, formants, rough, (5, 0.03), 0.4, bend=0.6) * envelope(1.0, 0.01, 0.8)
        if p.get("metal"):
            ring = np.sin(2 * np.pi * 1700 * times(0.3)) * np.exp(-times(0.3) * 12)
            hurt = mix(hurt, 0.5 * ring)
            death = mix(death, 0.4 * clicks(rng, 1.0, 5, 1500, 5000, 2.0))
        if p.get("dust"):
            death = mix(death, 0.5 * noise_burst(rng, 1.0, 1500, 7000, attack=0.2, release=0.7))
    elif family == "heart":
        beat = concat(thud(rng, 0.12, 70, 0.4, 0.2), thud(rng, 0.14, 55, 0.4, 0.2) * 0.8, gap=0.08)
        idle = mix(beat, 0.4 * band(rng.standard_normal(len(beat)), 100, 600) * envelope(len(beat) / RATE, 0.05, 0.1))
        hurt = mix(noise_burst(rng, 0.25, 100, 1200), voice(rng, 0.25, pitch * 1.5, pitch, formants, 0.5) * 0.5)
        death = mix(concat(beat, beat * 0.6, beat * 0.3, gap=0.3), 0.5 * voice(rng, 1.3, pitch, pitch * 0.4, formants, 0.6, breath=0.5) * envelope(1.3, 0.1, 1.0))
    elif family == "shriek":
        idle = mix(chirp(rng, 0.5, pitch, pitch * 1.4, 0.1), 0.3 * noise_burst(rng, 0.5, 2000, 7000))
        hurt = mix(chirp(rng, 0.25, pitch * 1.6, pitch * 1.1, 0.15), 0.4 * noise_burst(rng, 0.25, 2500, 8000))
        death = mix(chirp(rng, 0.9, pitch * 1.5, pitch * 0.5, 0.1), 0.4 * noise_burst(rng, 0.9, 1500, 7000, release=0.8))
        if p.get("storm"):
            death = mix(death, 0.6 * crackle(rng, 0.9, 120))
    elif family == "cackle":
        laugh = [voice(rng, 0.08, pitch * rng.uniform(1.0, 1.3), pitch * 0.9, formants, 0.4, breath=0.2) * envelope(0.08, 0.004, 0.05) for _ in range(5)]
        idle = mix(concat(*laugh, gap=0.04), 0.4 * crackle(rng, 0.6, 30))
        hurt = voice(rng, 0.2, pitch * 2.0, pitch * 1.4, formants, 0.4) * envelope(0.2, 0.005, 0.15)
        death = mix(voice(rng, 0.7, pitch * 2.0, pitch * 0.6, formants, 0.4) * envelope(0.7, 0.005, 0.6), crackle(rng, 0.7, 70) * 0.5)
    else:
        raise ValueError(family)
    return idle, hurt, death


# --- who sounds like what. Pitch in Hz; f1/f2 the mouth; rough the grit;
# foot the footstep; weight how heavy the step.
CREATURES = {
    "husk": ("groan", {"pitch": 95, "f1": 480, "f2": 1050, "rough": 0.5}, "shuffle", 1.0),
    "rot_hound": ("canine", {"pitch": 230, "f1": 700, "f2": 1600}, "paw", 1.0),
    "bone_archer": ("grunt", {"pitch": 120, "f1": 420, "f2": 1300, "rough": 0.7, "dust": True}, "clank", 0.8),
    "bog_slime": ("slime", {"pitch": 180}, "squish", 1.0),
    "carrion_bat": ("chirp", {"pitch": 2400, "notes": 4}, "wing", 1.0),
    "thorn_stalker": ("hiss", {"pitch": 400}, "creak", 0.9),
    "spore_shambler": ("wood", {"pitch": 160, "f1": 380, "f2": 900, "spores": True}, "squish", 1.2),
    "rot_cultist": ("grunt", {"pitch": 135, "f1": 650, "f2": 1200, "rough": 0.3, "chant": True}, "shuffle", 1.0),
    "ember_wisp": ("spirit", {"pitch": 520, "f1": 900, "f2": 2600, "fire": True}, "drift", 1.0),
    "ash_wraith": ("spirit", {"pitch": 310, "f1": 600, "f2": 1700}, "drift", 1.0),
    "crag_golem": ("rock", {"pitch": 60, "f1": 300, "f2": 700, "rough": 0.5}, "heavy", 1.0),
    "deer": ("bleat", {"pitch": 520, "f1": 900, "f2": 2200, "rough": 0.1, "vibrato": (6, 0.03)}, "hoof", 1.0),
    "wild_hare": ("squeak", {"pitch": 1500}, "hop", 1.0),
    "wild_pig": ("oink", {"pitch": 210, "f1": 600, "f2": 1300}, "hoof", 0.8),
    "mountain_goat": ("bleat", {"pitch": 410, "f1": 760, "f2": 1900, "rough": 0.3, "vibrato": (11, 0.08)}, "hoof", 0.9),
    "pheasant": ("chirp", {"pitch": 1700, "notes": 2}, "peck", 1.0),
    "desert_lizard": ("hiss", {"pitch": 600}, "skitter", 1.0),
    "snow_fox": ("canine", {"pitch": 520, "f1": 1100, "f2": 2400, "barks": True}, "paw", 0.7),
    "shore_crab": ("insect", {"pitch": 1800, "clicks": 7}, "skitter", 1.0),
    "marsh_toad": ("croak", {"pitch": 110, "f1": 450, "f2": 1100}, "squish", 0.8),
    "sheep": ("bleat", {"pitch": 330, "f1": 700, "f2": 1700, "rough": 0.2, "vibrato": (8, 0.07)}, "hoof", 0.9),
    "cow": ("moo", {"pitch": 105, "f1": 520, "f2": 1000, "rough": 0.2}, "hoof", 1.3),
    "chicken": ("cluck", {"pitch": 620, "f1": 1200, "f2": 2600}, "peck", 1.0),
    "bear": ("roar", {"pitch": 115, "f1": 420, "f2": 950, "rough": 0.5}, "heavy", 0.7),
    "grey_wolf": ("canine", {"pitch": 260, "f1": 750, "f2": 1700, "howl": True}, "paw", 1.0),
    "giant_spider": ("insect", {"pitch": 900, "clicks": 12}, "skitter", 1.0),
    "web_spider": ("insect", {"pitch": 1500, "clicks": 16}, "skitter", 1.0),
    "frost_wolf": ("canine", {"pitch": 300, "f1": 820, "f2": 2100, "howl": True}, "paw", 1.0),
    "frost_troll": ("roar", {"pitch": 78, "f1": 350, "f2": 800, "rough": 0.7}, "heavy", 1.1),
    "dire_boar": ("oink", {"pitch": 140, "f1": 480, "f2": 1050}, "hoof", 1.2),
    "treant": ("wood", {"pitch": 70, "f1": 300, "f2": 750}, "creak", 1.0),
    "sand_scorpion": ("insect", {"pitch": 1200, "clicks": 9}, "skitter", 1.0),
    "dune_mummy": ("grunt", {"pitch": 100, "f1": 500, "f2": 1100, "rough": 0.6, "dust": True}, "shuffle", 1.0),
    "void_stalker": ("spirit", {"pitch": 180, "f1": 500, "f2": 1400, "warp": 37}, "paw", 0.9),
    "void_eye": ("spirit", {"pitch": 700, "f1": 1200, "f2": 3000, "warp": 61}, "drift", 1.0),
    "crimson_fiend": ("roar", {"pitch": 150, "f1": 600, "f2": 1500, "rough": 0.8}, "paw", 1.2),
    "veinheart": ("heart", {"pitch": 90, "f1": 400, "f2": 900}, "squish", 1.0),
    "heartsworn_knight": ("grunt", {"pitch": 110, "f1": 550, "f2": 1150, "rough": 0.4, "metal": True}, "clank", 1.2),
    "rotten_corpse": ("groan", {"pitch": 80, "f1": 420, "f2": 900, "rough": 0.8}, "shuffle", 1.1),
    "ghost": ("spirit", {"pitch": 420, "f1": 750, "f2": 2000}, "drift", 1.0),
    "magma_slime": ("slime", {"pitch": 120, "fire": True}, "squish", 1.2),
    "cinder_imp": ("cackle", {"pitch": 420, "f1": 1000, "f2": 2400}, "paw", 0.7),
    "bog_lurker": ("croak", {"pitch": 70, "f1": 350, "f2": 800}, "squish", 1.3),
    "storm_harpy": ("shriek", {"pitch": 1300, "storm": True}, "wing", 1.0),
    "masked_noble": ("spirit", {"pitch": 150, "f1": 460, "f2": 1250}, "creak", 1.1),
    "matron": ("grunt", {"pitch": 215, "f1": 820, "f2": 1950, "rough": 0.15, "chant": True}, "shuffle", 0.9),
}


def main(only=None):
    for name, (family, profile, foot, weight) in CREATURES.items():
        if only and name not in only:
            continue
        rng = np.random.default_rng(zlib.crc32(name.encode()))
        idle, hurt, death = calls(rng, family, profile)
        # Every creature's own tempo and pitch on top, so kin in one family
        # never sound alike.
        tempo = [rng.uniform(0.78, 1.28) for _ in range(4)]
        write(name + "_idle", stretch(idle, tempo[0]))
        write(name + "_hurt", stretch(hurt, tempo[1]))
        write(name + "_death", stretch(death, tempo[2]))
        write(name + "_step", stretch(step_sound(rng, foot, weight), tempo[3]))
    print("creature sounds:", len(CREATURES) * 4)


if __name__ == "__main__":
    main()
