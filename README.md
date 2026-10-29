# ASCENSION VECTOR: C64 port

A PAL Commodore 64 demo version of the browser demo "Ascension Vector". It is written entirely in
6502 machine code (64tass). The only BASIC is the `SYS` stub.

* `ascension_vector.prg`: exomizer-crunched, so load it and `RUN` it (`LOAD"*",8,1` from the disk works too).
* `ascension_vector.d64`: disk image with the program on it.
* `preview.mp4`: 20 s captured from VICE (x64sc, 6581) with audio.
* `shots/`: VICE screenshots and a contact sheet.
* `src/main.s`: engine (IRQ/NMI, SID player, scenes). `tools/`: Python data and music generators. `build.sh` builds everything.

Run it in VICE with `x64sc -sidmodel 0 ascension_vector.prg`. Use a **6581** SID: the drop digis are played through $D418.

## Parts (beat-locked, about 2:55 loop)
The music player's beat counter drives the cuts. A timeline (`TL0..TL3[bar]`) can change scene on any
beat of each of the 108 bars (206 cuts in total). Every beat also gives a "crash-zoom" speed boost. Drops cut harder
and make the Watchers' eyes snap to the viewer.

Galaxy intro (spiral and outward star sprites) → title card ("ASCENSION VECTOR / 963 HZ" with FLD raster
bars) → hyper tunnel and 3D starfield → pentagram, Metatron's cube, and eye-in-triangle with a tracking iris →
rotating cube and ring sprite "vector" objects → messages that decode out of random glyphs → big-character word
flashes on beats → ringed planet (multicolour bitmap) → Watchers (7 PETSCII eyes with iris sprites, which look
around, blink, and snap on the drop) and a big expanded-sprite eye → precalculated Mandelbrot zoom (6 frames,
palette cycling) → plasma and geometric XOR/diamond/ring patterns → credits. A hardware smooth-scroller of
44 cryptic messages runs on the bottom row throughout. The palettes are deep blue, purple, cyan, and gold.

## Music, from Dave's track
`tools/analyse.py` takes `music.wav` and `beats.json` and produces `tools/analysis.json`:
* 148.06 BPM. The key is **E Phrygian dominant** (E F G# A B C D) over an E/B drone. Krumhansl first said
  "B major" because of the drone. Bass is about 80 Hz (E2). Chord motion is mostly E, then F, Dm, G#m.
* Four-on-the-floor kick, 16th rolling psy bass, offbeat hats, and snare rolls in builds.
* Sections and drops come from beats.json (drops at 8.3, 123.4, 253.1, 377.9, 429.8, 450.8 s).

`tools/gensong.py` writes a 3-voice SID arrangement with the same structure compressed into 108 bars
(intro, build, drop, break ×4, outro):
* V1: kick (noise→triangle pitch sweep) plus rolling saw bass through a resonant low-pass sweep.
* V2: hats, snare rolls, and the 963 Hz sine-like tone in the intros and breaks.
* V3: PWM pulse arpeggio on drops, Phrygian lead motif with vibrato in breaks.
* Digi: 4352 bytes of the real recording, taken from the 123.4 s drop. It is played at 7.8 kHz as 4-bit samples on
  the NMI (CIA2 timer) through $D418 at the start of each drop. This costs about 25-30 cycles per sample, which is
  roughly 15% of CPU for the 0.56 s it plays. The synth is muted during the hit.

How faithful it is: tempo, key, groove, structure and drops match the original. The bass line and arp follow the
extracted chords. The lead is a written motif in the same mode, **not** a transcription. The sound is
chiptune and the original's timbre is only heard in the digi hits.

## Technical
* VIC bank 3: text screen $C000, bitmap colours $C400, charset $C800 (ROM chars plus quadrant, dither, star and glyph chars),
  sprites $D000 (under I/O), bitmap $E000. Code and data are at $0801–$BDE0.
* IRQs: top (VIC shadow registers, sprites, music, scroller) → FLD bars ($2E, title and credits only) or
  split at $F0 (switches to text mode with fine X scroll for the scroller row).
* Colour effects: unrolled table renderers over 960 colour-RAM cells.
  `PAL[(T1+t1)]` takes about 22 cycles per cell, and `PAL[(T1+t1)^(T2+t2)]` takes about 35 cycles per cell.

## Caveats
* The $D418 digi is only audible on a 6581. On an 8580 it is near-silent.
* The raster bars use FLD with polling rather than cycle-exact stable rasters, so expect slight jitter. The
  effects run at 25–50 fps rather than a locked 50 Hz in the dual-table scenes.
* There is no sprite multiplexer: at most 8 sprites are on screen. The galaxy and the fractal are char-based or precalculated
  (6 fractal frames), so they are lower resolution than the browser version.
* The title-card colour sweep briefly passes through dark colours, so letters can blink out for a moment.
* It has been tested in VICE 3.9 x64sc (PAL, 6581) only. It has not been tried on real hardware.
