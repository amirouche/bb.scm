#!/bin/sh

set -eo pipefail

args=""
for a in "$@"; do args="$args \"$a\""; done


(echo "(import (bb cli)) (apply main (list $args))"; cat) | scheme --quiet --libdirs ./src/
