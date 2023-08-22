#! /bin/bash

set -eux
# Couldn't find a way to run netserver in the foreground.
netserver $@
echo "Started echo server."
ncat -e /bin/cat -k -l 6789 &
echo "Started TCP ping server"
fortio server &
python3 -m http.server &
sleep 365d
