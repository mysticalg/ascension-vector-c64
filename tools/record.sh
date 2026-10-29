#!/bin/sh
# Records ~36 s of VICE (real time) under Xvfb: video via x11grab, audio via VICE's wav sound device.
cd "$(dirname "$0")/.."
Xvfb :77 -screen 0 800x600x24 >/dev/null 2>&1 &
XP=$!; sleep 1
DISPLAY=:77 nice -n 10 x64sc -default -sidmodel 0 -sounddev wav -soundarg build/rec.wav -limitcycles 37000000 -autostartprgmode 1 -autostart ascension_vector.prg >/dev/null 2>&1 &
sleep 0.3
nice -n 10 ffmpeg -loglevel error -y -f x11grab -framerate 25 -video_size 800x600 -i :77 -t 36 build/rec.mkv
wait $!; kill $XP
