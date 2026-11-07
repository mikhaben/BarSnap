#!/bin/sh
set -e
cd "$(dirname "$0")"
luacheck .
ast-grep scan
find . -name '*.lua' -not -path '*/Libs/*' -not -path './build/*' -exec wc -l {} + | awk -v cap=1000 -v freeze=file-length-freeze.txt '
  BEGIN { while ((getline line < freeze) > 0) { split(line, f, " "); limit["./" f[1]] = f[2] } }
  $2 != "total" { max = ($2 in limit) ? limit[$2] : cap
    if ($1 > max) { printf "%s has %d lines; the limit is %d. Split it by responsibility.\n", $2, $1, max; bad = 1 } }
  END { exit bad }'
