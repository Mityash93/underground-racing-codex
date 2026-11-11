"""Generate the project's original 32-bar electronic racing loop, using only Python stdlib.
No samples, recordings, arrangements or melodies from other games are used.
"""
from array import array
from pathlib import Path
import math
import random
import sys
import wave

RATE = 22050
BPM = 132
BEAT = 60 / BPM
BARS = 32
COUNT = round(BARS * 4 * BEAT * RATE)
TAU = math.tau


def create_track(destination: Path) -> None:
    mix = array('f', [0.0]) * COUNT
    rng = random.Random(9326)

    def add(start, duration, synth, gain=1.0):
        first = round(start * RATE)
        for j in range(round(duration * RATE)):
            mix[(first + j) % COUNT] += gain * synth(j / RATE)

    def kick(t):
        phase = TAU * (47 * t + 95 * 0.028 * (1 - math.exp(-t / 0.028)))
        return math.sin(phase) * math.exp(-t * 13) * 0.75

    def snare(t):
        return (rng.uniform(-1, 1) * 0.65 + math.sin(TAU * 185 * t) * 0.25) * math.exp(-t * 27)

    def hat(t):
        return rng.uniform(-1, 1) * math.exp(-t * 100) * 0.17

    def note(freq, duration, bright=False):
        def synth(t):
            attack = min(1.0, t / 0.006)
            release = min(1.0, max(0.0, (duration - t) / 0.045))
            envelope = attack * release * math.exp(-t * (4.5 if bright else 1.5))
            phase = TAU * freq * t
            tone = math.sin(phase) + 0.30 * math.sin(phase * 2) + 0.12 * math.sin(phase * 3)
            if bright:
                tone += 0.12 * math.sin(phase * 4)
            return tone * envelope
        return synth

    # Original progression: E minor / C / G / D; each harmony lasts two bars.
    roots = [40, 36, 43, 38]
    riff = [0, 7, 12, 10, 7, 3, 5, 7]
    for bar in range(BARS):
        base = bar * 4 * BEAT
        root = roots[(bar // 2) % len(roots)]
        intensity = 0.65 if bar < 4 or 16 <= bar < 20 else 1.0
        for beat in [0, 1, 2, 3]:
            add(base + beat * BEAT, 0.38, kick, intensity)
        if bar >= 2:
            for beat in [1, 3]:
                add(base + beat * BEAT, 0.20, snare, 0.43 * intensity)
        for step in range(8):
            add(base + step * BEAT / 2, 0.055, hat, 0.70 if step % 2 else 0.48)
            midi = root + (12 if step in [3, 7] else 0)
            freq = 440 * 2 ** ((midi - 69) / 12)
            add(base + step * BEAT / 2, BEAT * 0.40, note(freq, BEAT * 0.40), 0.24)
        if 4 <= bar < 16 or bar >= 20:
            for step in range(8):
                midi = root + 24 + riff[(step + (2 if bar % 4 == 3 else 0)) % 8]
                freq = 440 * 2 ** ((midi - 69) / 12)
                at = base + step * BEAT / 2
                add(at, BEAT * 0.43, note(freq, BEAT * 0.43, True), 0.095)
                add(at + BEAT * 0.75, BEAT * 0.43, note(freq, BEAT * 0.43, True), 0.025)
        # Low sustained chord bed, with attack/release at every bar.
        for interval in [12, 15 if (bar // 2) % 4 == 0 else 16, 19]:
            freq = 440 * 2 ** ((root + interval - 69) / 12)
            add(base, BEAT * 3.9, note(freq, BEAT * 3.9), 0.033)
        if bar % 8 == 7:
            for beat in [3.25, 3.5, 3.75]:
                add(base + beat * BEAT, 0.12, snare, 0.23)

    peak = max(abs(sample) for sample in mix)
    pcm = array('h', (int(max(-1, min(1, sample / peak * 0.88)) * 32767) for sample in mix))
    if sys.byteorder != 'little':
        pcm.byteswap()
    destination.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(destination), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    print(f'Created {destination}: {COUNT / RATE:.2f}s, {BPM} BPM, peak normalized to 0.88')


if __name__ == '__main__':
    create_track(Path(__file__).resolve().parents[1] / 'assets/audio/neon_pulse.wav')
