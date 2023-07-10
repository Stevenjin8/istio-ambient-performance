#! /bin/bash

set -eux
echo "Starting netserver."
# Couldn't find a way to run netserver in the foreground.
netserver $@
echo "Starting echo server."
ncat -e /bin/cat -k -l 6789 &
echo "Started netserver. Sleeping."
sleep 365d
