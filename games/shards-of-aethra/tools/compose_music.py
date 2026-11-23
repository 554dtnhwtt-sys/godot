"""Compose the three Shards of Aethra music loops as MIDI and render them with FluidSynth.

Usage: python compose_music.py soundfont.sf2 out_dir
Tracks: theme (title screen), planning (shopping phase), combat (fights).
Each track is written so that its end flows back into its start, so it loops.
"""
import os
import random
import subprocess
import sys

import mido

TPB = 480  # ticks per beat
NOTE = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6, 'Gb': 6,
        'G': 7, 'G#': 8, 'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11}


def n(name):
    """'D5' -> midi number."""
    pitch, octave = name[:-1], int(name[-1])
    return 12 * (octave + 1) + NOTE[pitch]


# chord symbol -> (root pitch class, intervals)
CHORDS = {
    'Dm': (2, [0, 3, 7]), 'Bb': (10, [0, 4, 7]), 'F': (5, [0, 4, 7]), 'C': (0, [0, 4, 7]),
    'Gm': (7, [0, 3, 7]), 'A': (9, [0, 4, 7]), 'Asus': (9, [0, 5, 7]), 'Am': (9, [0, 3, 7]),
    'Eb': (3, [0, 4, 7]), 'Cm': (0, [0, 3, 7]), 'Fsus': (5, [0, 5, 7]), 'Dsus': (2, [0, 5, 7]),
    'Bbmaj7': (10, [0, 4, 7, 11]), 'Fmaj7': (5, [0, 4, 7, 11]), 'Gm7': (7, [0, 3, 7, 10]),
}


class Song:
    def __init__(self, bpm):
        self.bpm = bpm
        self.events = {}  # channel -> list of (tick, msg)
        self.programs = {}

    def program(self, ch, prog, vol=100, pan=64, reverb=60, chorus=0):
        self.programs[ch] = (prog, vol, pan, reverb, chorus)

    def note(self, ch, pitch, start_beat, dur_beats, vel=90):
        t0 = int(round(start_beat * TPB))
        t1 = int(round((start_beat + dur_beats) * TPB)) - 8
        ev = self.events.setdefault(ch, [])
        ev.append((t0, 1, mido.Message('note_on', channel=ch, note=int(pitch), velocity=int(max(1, min(127, vel))))))
        ev.append((max(t0 + 10, t1), 0, mido.Message('note_off', channel=ch, note=int(pitch), velocity=0)))

    def cc(self, ch, ctrl, value, beat):
        self.events.setdefault(ch, []).append((int(beat * TPB), 0, mido.Message('control_change', channel=ch, control=ctrl, value=int(value))))

    def save(self, path, total_beats):
        mid = mido.MidiFile(ticks_per_beat=TPB)
        meta = mido.MidiTrack()
        meta.append(mido.MetaMessage('set_tempo', tempo=mido.bpm2tempo(self.bpm), time=0))
        meta.append(mido.MetaMessage('end_of_track', time=int(total_beats * TPB) + TPB * 6))
        mid.tracks.append(meta)
        for ch, evs in sorted(self.events.items()):
            tr = mido.MidiTrack()
            prog, vol, pan, rev, cho = self.programs.get(ch, (0, 100, 64, 50, 0))
            if ch != 9:
                tr.append(mido.Message('program_change', channel=ch, program=prog, time=0))
            for ctrl, val in ((7, vol), (10, pan), (91, rev), (93, cho)):
                tr.append(mido.Message('control_change', channel=ch, control=ctrl, value=val, time=0))
            last = 0
            for t, _, msg in sorted(evs, key=lambda e: (e[0], e[1])):
                tr.append(msg.copy(time=t - last))
                last = t
            mid.tracks.append(tr)
        mid.save(path)


def chord_notes(sym, base_oct=4, inversion=0):
    root, ints = CHORDS[sym]
    notes = [12 * (base_oct + 1) + root + i for i in ints]
    for _ in range(inversion):
        notes = notes[1:] + [notes[0] + 12]
    return notes


def bass_note(sym, octave=2):
    return 12 * (octave + 1) + CHORDS[sym][0]


# ─────────────────────────────────────────── THEME ───────────────────────────────────────────
def compose_theme():
    s = Song(76)
    s.program(0, 48, 92, 54, 90)    # strings
    s.program(1, 52, 70, 70, 100)   # choir
    s.program(2, 60, 104, 60, 80)   # french horn (melody)
    s.program(3, 46, 78, 84, 70)    # harp
    s.program(4, 47, 96, 64, 60)    # timpani
    s.program(5, 42, 88, 40, 70)    # cello
    s.program(6, 73, 80, 90, 80)    # flute
    s.program(7, 8, 60, 76, 90)     # celesta
    s.program(8, 57, 92, 64, 70)    # trombone
    prog = ['Dm', 'Bb', 'F', 'C', 'Gm', 'Bb', 'Asus', 'A'] * 2 + ['Dm', 'Bb', 'F', 'C', 'Gm', 'Eb', 'Asus', 'A']
    # melody (beats): two phrases of 8 bars, horn then strings+flute an octave up
    mel = [('D5', 2), ('F5', 1), ('A5', 1), ('Bb5', 3), ('A5', .5), ('G5', .5), ('A5', 2), ('F5', 1), ('C6', 1), ('G5', 3), ('E5', 1),
           ('G5', 2), ('Bb5', 1), ('D6', 1), ('F5', 2), ('D5', 1), ('F5', 1), ('E5', 2), ('C#5', 1), ('E5', 1), ('A4', 4)]
    mel2 = [('A5', 1.5), ('G5', .5), ('F5', 1), ('A5', 1), ('D6', 3), ('C6', 1), ('A5', 2), ('C6', 1), ('F6', 1), ('E6', 3), ('C6', 1),
            ('D6', 2), ('Bb5', 1), ('G5', 1), ('Eb6', 2), ('D6', 1), ('Bb5', 1), ('A5', 2), ('C#6', 1), ('E6', 1), ('D6', 4)]
    bars = len(prog)
    for b, sym in enumerate(prog):
        t = b * 4
        section = b // 8
        vel = 58 + section * 14
        # sustained strings voicing
        for p in chord_notes(sym, 4, b % 2):
            s.note(0, p, t, 4, vel)
        s.note(5, bass_note(sym, 2), t, 4, vel + 8)
        if section >= 1:
            s.note(5, bass_note(sym, 3), t, 4, vel)
        # choir swells from the second section
        if section >= 1:
            for p in chord_notes(sym, 4, 1):
                s.note(1, p, t, 4, vel - 6)
        # harp arpeggio, eighth notes
        arp = chord_notes(sym, 3) + chord_notes(sym, 4) + [chord_notes(sym, 5)[0]]
        pattern = [0, 1, 2, 3, 4, 5, 6, 4]
        for i in range(8):
            s.note(3, arp[pattern[i] % len(arp)], t + i * .5, .9, 52 + (12 if i == 0 else 0))
        # timpani on bar starts in later sections, roll into the cadence
        if section >= 1:
            s.note(4, bass_note(sym, 2), t, 1, 80 + section * 8)
            if sym == 'A':
                for k in range(8):
                    s.note(4, n('A2'), t + 2 + k * .25, .25, 60 + k * 6)
        # trombone pedal in the final section
        if section == 2:
            s.note(8, bass_note(sym, 3), t, 4, 70)
        # celesta sparkle
        if b % 2 == 0:
            s.note(7, chord_notes(sym, 6)[1], t + 3.5, .5, 50)
    beat = 0
    for name, d in mel:
        s.note(2, n(name), 4 * 8 + beat, d, 92)
        beat += d
    beat = 0
    for name, d in mel2:
        s.note(6, n(name), 4 * 16 + beat, d, 88)
        s.note(0, n(name) - 12, 4 * 16 + beat, d, 92)
        beat += d
    # quiet opening: flute hints the theme
    beat = 0
    for name, d in mel[:7]:
        s.note(6, n(name), beat + 4, d, 60)
        beat += d
    return s, bars * 4


# ─────────────────────────────────────────── PLANNING ───────────────────────────────────────────
def compose_planning():
    s = Song(98)
    s.program(0, 45, 84, 50, 50)    # pizzicato strings
    s.program(1, 46, 80, 80, 70)    # harp
    s.program(2, 73, 86, 74, 70)    # flute
    s.program(3, 49, 64, 64, 90)    # slow strings pad
    s.program(4, 32, 86, 64, 40)    # acoustic bass
    s.program(5, 71, 74, 44, 60)    # clarinet countermelody
    s.program(6, 8, 52, 90, 80)     # celesta
    s.program(9, 0, 70, 64, 40)     # drums
    prog = ['F', 'C', 'Dm', 'Bb', 'F', 'C', 'Gm', 'C', 'Dm', 'Bb', 'F', 'C', 'Gm', 'Bb', 'Csus' if False else 'C', 'C']
    mel = [('C5', 1), ('F5', 1), ('G5', 1), ('A5', 1), ('G5', 2), ('E5', 1), ('C5', 1), ('D5', 1.5), ('E5', .5), ('F5', 1), ('A5', 1), ('Bb5', 2), ('A5', 1), ('G5', 1),
           ('A5', 1), ('C6', 1), ('Bb5', 1), ('A5', 1), ('G5', 2), ('C5', 1), ('E5', 1), ('G5', 1.5), ('F5', .5), ('E5', 1), ('D5', 1), ('E5', 4)]
    counter = [('A4', 2), ('G4', 2), ('F4', 2), ('E4', 2), ('D4', 2), ('F4', 2), ('Bb4', 2), ('A4', 2),
               ('A4', 2), ('C5', 2), ('Bb4', 2), ('A4', 2), ('G4', 2), ('F4', 2), ('E4', 2), ('G4', 2)]
    for b, sym in enumerate(prog):
        t = b * 4
        if b >= 8:
            for p in chord_notes(sym, 4, 1):
                s.note(3, p, t, 4, 50)
        # pizzicato: bass + chord on 2 and 4
        cn = chord_notes(sym, 4)
        s.note(4, bass_note(sym, 2), t, 1, 84)
        s.note(4, bass_note(sym, 2) + 7, t + 2, 1, 74)
        s.note(4, bass_note(sym, 2) + 12, t + 3.5, .5, 64)
        for beat in (1, 3):
            for p in cn:
                s.note(0, p, t + beat, .5, 62)
        s.note(0, cn[0] + 12, t + 2.5, .5, 54)
        # harp broken chord, sixteenths on beat 4
        up = chord_notes(sym, 5)
        for k, p in enumerate(up + [up[0] + 12]):
            s.note(1, p, t + 3 + k * .25, .5, 46 + k * 4)
        # soft drums: brush-like
        s.note(9, 36, t, .5, 58)
        s.note(9, 36, t + 2.5, .5, 44)
        for k in range(4):
            s.note(9, 42, t + k + .5, .25, 34)
        s.note(9, 39 if b % 2 else 37, t + 2, .5, 40)
        if b % 4 == 3:
            s.note(6, chord_notes(sym, 6)[2], t + 3.5, .5, 46)
    beat = 0
    for name, d in mel:
        s.note(2, n(name), 4 * 4 + beat, d, 86)
        beat += d
    beat = 0
    for name, d in counter:
        s.note(5, n(name), 4 * 0 + beat, d, 58)
        beat += d
    return s, len(prog) * 4


# ─────────────────────────────────────────── COMBAT ───────────────────────────────────────────
def compose_combat():
    s = Song(136)
    s.program(0, 48, 96, 54, 40)    # string ostinato
    s.program(1, 61, 100, 70, 50)   # brass section
    s.program(2, 116, 110, 64, 30)  # taiko
    s.program(3, 47, 100, 64, 40)   # timpani
    s.program(4, 52, 80, 64, 90)    # choir
    s.program(5, 60, 104, 80, 60)   # horns melody
    s.program(6, 43, 100, 40, 40)   # contrabass
    s.program(7, 117, 90, 90, 30)   # melodic toms
    s.program(9, 0, 92, 64, 30)     # kit (cymbals)
    prog = ['Dm', 'Dm', 'Bb', 'C', 'Dm', 'Dm', 'Gm', 'A', 'Dm', 'Bb', 'F', 'C', 'Gm', 'Bb', 'Asus', 'A']
    mel = [('A4', 1.5), ('D5', 1.5), ('E5', 1), ('F5', 3), ('E5', 1), ('D5', 1.5), ('C5', 1.5), ('Bb4', 1), ('C5', 4),
           ('A4', 1.5), ('D5', 1.5), ('F5', 1), ('A5', 3), ('G5', 1), ('F5', 1.5), ('E5', 1.5), ('D5', 1), ('E5', 4),
           ('F5', 2), ('A5', 2), ('Bb5', 3), ('A5', 1), ('G5', 2), ('F5', 1), ('E5', 1), ('F5', 2), ('D5', 2),
           ('G5', 1.5), ('F5', 1.5), ('E5', 1), ('D5', 3), ('F5', 1), ('E5', 2), ('C#5', 2), ('E5', 4)]
    rnd = random.Random(7)
    for b, sym in enumerate(prog):
        t = b * 4
        root = bass_note(sym, 3)
        fifth = root + 7
        pat = [0, 0, 7, 0, 12, 0, 7, 3 if CHORDS[sym][1][1] == 3 else 4]
        for k in range(8):
            accent = 90 if k in (0, 3, 6) else 66
            s.note(0, root + pat[k], t + k * .5, .45, accent)
            s.note(0, root + pat[k] + 12, t + k * .5, .45, accent - 12)
        s.note(6, bass_note(sym, 2), t, 1.5, 96)
        s.note(6, bass_note(sym, 2), t + 1.5, 1, 86)
        s.note(6, bass_note(sym, 2), t + 3, 1, 86)
        # brass stabs
        for beat, d, v in ((0, .75, 104), (1.5, .5, 92), (3, 1, 98)):
            for p in chord_notes(sym, 3, 1):
                s.note(1, p, t + beat, d, v)
        # taiko groove
        for beat, v in ((0, 118), (1.5, 96), (2, 108), (3, 104), (3.5, 90), (3.75, 84)):
            s.note(2, n('C3'), t + beat, .5, v)
        if b % 4 == 3:
            for k in range(8):
                s.note(7, n('G3') - k, t + 2 + k * .25, .25, 70 + k * 5)
        s.note(3, bass_note(sym, 2), t, 1, 100)
        if b % 2 == 1:
            s.note(3, bass_note(sym, 2) + 7, t + 2, 1, 88)
        # cymbals
        if b % 4 == 0:
            s.note(9, 49, t, 2, 92)
        s.note(9, 42, t + 1, .25, 50)
        s.note(9, 42, t + 3, .25, 50)
        # choir on the second half
        if b >= 8:
            for p in chord_notes(sym, 4):
                s.note(4, p, t, 4, 80)
    beat = 0
    for name, d in mel:
        s.note(5, n(name), beat, d, 106)
        s.note(5, n(name) - 12, beat, d, 90)
        beat += d
    return s, len(prog) * 4


def render(song, beats, name, sf2, out_dir, tmp):
    mid = os.path.join(tmp, name + '.mid')
    wav = os.path.join(tmp, name + '.wav')
    song.save(mid, beats)
    subprocess.run(['fluidsynth', '-ni', '-g', '0.55', '-r', '44100', '-F', wav, sf2, mid], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    seconds = beats * 60.0 / song.bpm
    # Fold the reverb tail back onto the start so the loop is seamless.
    tail = 2.5
    dst = os.path.join(out_dir, name + '.mp3')
    filt = (f'[0:a]atrim=0:{seconds:.3f},asetpts=N/SR/TB[body];'
            f'[0:a]atrim={seconds:.3f}:{seconds + tail:.3f},asetpts=N/SR/TB,afade=t=out:d={tail}[tail];'
            f'[body][tail]amix=inputs=2:duration=first:normalize=0,loudnorm=I=-18:TP=-1.5:LRA=11[out]')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-filter_complex', filt, '-map', '[out]',
                    '-ar', '44100', '-c:a', 'libmp3lame', '-b:a', '128k', dst], check=True)
    print(name, f'{seconds:.1f}s', os.path.getsize(dst) // 1024, 'KB')


def main():
    sf2, out_dir = sys.argv[1:3]
    tmp = os.path.join(os.path.dirname(os.path.abspath(out_dir)), '..', '.music_tmp')
    tmp = os.environ.get('MUSIC_TMP', tmp)
    os.makedirs(tmp, exist_ok=True)
    os.makedirs(out_dir, exist_ok=True)
    for name, fn in (('theme', compose_theme), ('planning', compose_planning), ('combat', compose_combat)):
        song, beats = fn()
        render(song, beats, name, sf2, out_dir, tmp)


if __name__ == '__main__':
    main()
