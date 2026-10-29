#!/bin/sh
# usage: shot.sh seconds outfile
cyc=$(python3 -c "print(int(($1)*985248))")
nice -n 15 xvfb-run -a x64sc -default -sidmodel 0 -sounddev dummy -warp -autostart-warp -limitcycles $cyc -exitscreenshot "$2" -autostartprgmode 1 -autostart "$(dirname $0)/../ascension_vector.prg" >/dev/null 2>&1
