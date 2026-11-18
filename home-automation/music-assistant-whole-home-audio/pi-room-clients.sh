#!/bin/sh
# Turn a Raspberry Pi with speakers into a Music Assistant room.
# Run ONE of these on the Pi. MA_IP is the Music Assistant server.
MA_IP=192.168.1.10

# Option 1: Snapcast client against MA's built-in Snapserver
# (add the Snapcast player provider in MA first). Stream port 1704.
# snapclient --hostID kitchen "tcp://${MA_IP}:1704"

# Option 2: Squeezelite (slimproto, port 3483). Use the ALSA build.
# squeezelite -n "Kitchen" -s "${MA_IP}"

# List output devices first if the default one is wrong:
# snapclient --list
# squeezelite -l
