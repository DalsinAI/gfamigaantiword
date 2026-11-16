#!/bin/sh
# PC test: builds Antiword twice from the commit antiword.lock pins, as
# upstream (Linux) and from the patched sources with -D__amigaos (the
# code paths the Amiga build takes: AmigaDOS resource lookups), then
#  1. text, PostScript and PDF of upstream's Docs/testdoc.doc are the same
#     from both (dates and the user name taken out),
#  2. the text is tests/expected/testdoc.txt,
#  3. resources come from SYS:Utilities/Antiword (a directory of that name
#     here), from ANTIWORDHOME first, from HOME/.antiword with HOME a
#     volume name ("Work:"), and with no HOME there is no warning.
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu
# a step that stops the script says which one, in the build log
trap 'rc=$?; [ $rc = 0 ] || echo "host-antiword.sh: stopped (exit $rc), last step: ${STEP:-start}"' EXIT
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$HERE/antiword.lock"
. "$HERE/scripts/aw-common.sh"
CC=${HOST_CC:-cc}
WORK=${WORK:-"$HERE/build-host"}; mkdir -p "$WORK"; WORK=$(cd "$WORK" && pwd)
CF="-O2 -w -DNDEBUG"

# upstream as it is (Linux), and patched as on AmigaOS
STEP="fetch"
UP="$WORK/upstream"; fetch_at "$UP" "$AW_GIT" "$AW_COMMIT"
[ -f "$UP/fontinfo.h" ] || cp "$UP/Unix-only/fontinfo.h" "$UP/fontinfo.h"
SRC="$WORK/antiword"; aw_source "$SRC"
build() { # build DIR OUT EXTRA...
    d=$1; o=$2; shift 2
    # shellcheck disable=SC2086
    (cd "$d" && $CC $CF "$@" -o "$o" $AW_SRCS -lm)
}
mkdir -p "$WORK/up-bin" "$WORK/amiga-bin"
STEP="build"; echo "host cc: $($CC --version | head -1)"
build "$UP" "$WORK/up-bin/antiword" -DGLOBAL_ANTIWORD_DIR="\"$UP/Resources\""
build "$SRC" "$WORK/amiga-bin/antiword" -D__amigaos "$HERE/amiga/aw_path.c" -I"$HERE/amiga"

STEP="checks"
# a run directory with SYS:Utilities/Antiword as the part installs it
RUN="$WORK/run"; rm -rf "$RUN"; mkdir -p "$RUN/SYS:Utilities/Antiword"
for f in $(aw_resources "$SRC"); do cp "$SRC/Resources/$f" "$RUN/SYS:Utilities/Antiword/"; done
DOC="$SRC/Docs/testdoc.doc"
fail=0; n=0
ok() { n=$((n + 1)); }
bad() { echo "FAIL: $*"; fail=1; }
# what does not depend on the build: creation dates, the user's name
norm() { grep -v -e 'CreationDate' -e '^%%For:' -e '/Author' -e '/Creator' -e '/Producer' "$1" || true; }

for fmt in text ps pdf; do
    case $fmt in text) a="";; ps) a="-p a4";; pdf) a="-a a4";; esac
    # shellcheck disable=SC2086
    (cd "$RUN" && env -u HOME -u ANTIWORDHOME USER=t LOGNAME=t \
        "$WORK/up-bin/antiword" $a "$DOC" > "$WORK/up.$fmt" 2> "$WORK/up.$fmt.err") || bad "$fmt: upstream exit $?: $(head -2 "$WORK/up.$fmt.err")"
    # shellcheck disable=SC2086
    (cd "$RUN" && env -u HOME -u ANTIWORDHOME USER=t LOGNAME=t \
        "$WORK/amiga-bin/antiword" $a "$DOC" > "$WORK/am.$fmt" 2> "$WORK/am.$fmt.err") || bad "$fmt: patched exit $?: $(head -2 "$WORK/am.$fmt.err")"
    if [ ! -s "$WORK/am.$fmt" ]; then bad "$fmt: no output"; cat "$WORK/am.$fmt.err"; continue; fi
    norm "$WORK/up.$fmt" > "$WORK/up.$fmt.n"; norm "$WORK/am.$fmt" > "$WORK/am.$fmt.n"
    if cmp -s "$WORK/up.$fmt.n" "$WORK/am.$fmt.n"; then
        ok
    else
        bad "$fmt: differs from upstream"; diff "$WORK/up.$fmt.n" "$WORK/am.$fmt.n" | head -10
    fi
    # with no HOME, AmigaOS has nothing to warn about
    if [ -s "$WORK/am.$fmt.err" ]; then bad "$fmt: stderr: $(head -2 "$WORK/am.$fmt.err")"; else ok; fi
done
if cmp -s "$WORK/am.text" "$HERE/tests/expected/testdoc.txt"; then ok; else
    bad "text is not tests/expected/testdoc.txt"; diff "$HERE/tests/expected/testdoc.txt" "$WORK/am.text" | head -10
fi

# ANTIWORDHOME first: a fontnames there that is not the global one
mkdir -p "$RUN/Env:Antiword"
cp "$RUN/SYS:Utilities/Antiword/"*.txt "$RUN/Env:Antiword/"
sed 's/Helvetica-Bold\b/Palatino-Bold/g' "$RUN/SYS:Utilities/Antiword/fontnames" > "$RUN/Env:Antiword/fontnames"
(cd "$RUN" && env -u HOME ANTIWORDHOME="Env:Antiword" "$WORK/amiga-bin/antiword" -p a4 "$DOC" > "$WORK/env.ps" 2>&1) || bad "ANTIWORDHOME run exit $?: $(head -2 "$WORK/env.ps")"
if grep -q 'Palatino-Bold' "$WORK/env.ps"; then ok; else bad "ANTIWORDHOME fontnames not used"; fi
# HOME as a volume name: Work:.antiword, not Work:/.antiword
mkdir -p "$RUN/Work:.antiword"
sed 's/Helvetica-Bold\b/Bookman-Demi/g' "$RUN/SYS:Utilities/Antiword/fontnames" > "$RUN/Work:.antiword/fontnames"
(cd "$RUN" && env -u ANTIWORDHOME HOME="Work:" "$WORK/amiga-bin/antiword" -p a4 "$DOC" > "$WORK/home.ps" 2>&1) || bad "HOME=Work: run exit $?: $(head -2 "$WORK/home.ps")"
if grep -q 'Bookman-Demi' "$WORK/home.ps"; then ok; else bad "HOME=Work: fontnames not used"; fi
# a mapping file named with -m comes from the global drawer
(cd "$RUN" && env -u HOME -u ANTIWORDHOME "$WORK/amiga-bin/antiword" -m cp850.txt "$DOC" > "$WORK/cp850.txt" 2> "$WORK/cp850.err") || bad "-m cp850.txt exit $?"
if [ -s "$WORK/cp850.txt" ] && [ ! -s "$WORK/cp850.err" ]; then ok; else bad "-m cp850.txt: $(head -2 "$WORK/cp850.err")"; fi
# no resources at all: one clear message naming the drawer
mv "$RUN/SYS:Utilities" "$RUN/SYS:Gone"
if (cd "$RUN" && env -u HOME -u ANTIWORDHOME "$WORK/amiga-bin/antiword" "$DOC" > /dev/null 2> "$WORK/none.err"); then bad "ran with no resources"; fi
if grep -q 'SYS:Utilities/Antiword' "$WORK/none.err"; then ok; else bad "no-resources message: $(head -3 "$WORK/none.err")"; fi
mv "$RUN/SYS:Gone" "$RUN/SYS:Utilities"

[ $fail = 0 ] && echo "Antiword host: $n checks passed"
exit $fail
