#!/bin/sh
# PC test for scripts/write-part.sh: the Part file GFOpenUpTool reads.
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/C" "$T/Utilities/Antiword" "$T/Docs/Antiword"
: > "$T/C/antiword"; : > "$T/Utilities/Antiword/fontnames"; : > "$T/Utilities/Antiword/8859-1.txt"
: > "$T/Docs/Antiword/ReadMe"
sh "$HERE/../scripts/write-part.sh" "$T" 0.37
fail=0
expect() { grep -qxF "$1" "$T/Part" || { echo "FAIL: no line: $1"; fail=1; }; }
expect 'part Antiword 0.37'
expect 'needs 68040'
expect 'copy "C/antiword" "SYS:C/antiword"'
expect 'copy "Utilities/Antiword/fontnames" "SYS:Utilities/Antiword/fontnames"'
expect 'copy "Utilities/Antiword/8859-1.txt" "SYS:Utilities/Antiword/8859-1.txt"'
expect 'copy "Docs/Antiword/ReadMe" "SYS:Docs/Antiword/ReadMe"'
[ "$(head -1 "$T/Part")" = 'part Antiword 0.37' ] || { echo "FAIL: first line"; fail=1; }
[ "$(grep -c '^copy' "$T/Part")" = 4 ] || { echo "FAIL: file count (the Part file itself must not be listed)"; fail=1; }
sh "$HERE/../scripts/write-part.sh" "$T" 0.37   # a second run: the same file
[ "$(grep -c '^copy' "$T/Part")" = 4 ] || { echo "FAIL: second run lists the Part file"; fail=1; }
[ $fail = 0 ] && echo "Part file: all checks passed"
exit $fail
