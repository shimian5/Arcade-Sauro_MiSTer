#!/bin/bash
# Build tb_core and run the scripted-play simulation (MAME dump_frame.lua PLAY=1 inputs) for <ms> machine milliseconds.
# Usage: tools/wsl_play_run.sh <ms> [extra plusargs]; results in ~/sauro_sim/play_audio.log and play.raw
ms=$1; shift
bash "$(dirname "${BASH_SOURCE[0]}")/wsl_core_sim.sh" sauro +F0=1000000 +MS=100 > /dev/null 2>&1
cd $HOME/sauro_sim && ./obj/Vtb_core +IMAGE=image.hex +OUT=play +F0=1000000 +MS=$ms +PLAY +WAV "$@" 2>&1 | grep -E 'audio:|TIMEOUT'
