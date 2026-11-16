#!/bin/sh
# Builds Antiword, the MS Word document reader, for GFOS (AmigaOS 3.2.3
# with GFOpenUp) with a stove: 68040, soft float with the FPU taken when
# there is one (fpuauto).
#   STOVE=.../stoves/os32-gcc16-open6 OUT=out ./build-amiga.sh
# Antiword and fpuauto are fetched at the commits antiword.lock gives;
# nothing third-party is kept here. The PC tests (tests/host-antiword.sh:
# the same patched sources with the AmigaOS paths) run first when there
# is a PC compiler; HOST_TESTS=0 skips them.
# OUT gets Parts/Antiword: a GFOpenUp part (its Part file, C:antiword, the
# mapping files and font names in SYS:Utilities/Antiword, the manual and
# licences in SYS:Docs/Antiword), installed with
#   GFOpenUpTool INSTALL Parts/Antiword
# and tests/: upstream's testdoc.doc and its expected text, for a lab.
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu
# everything on stdout: the stove log keeps only stdout
exec 2>&1
# the stage a failure stopped in, in the stove log
STAGE=start
trap 'rc=$?; [ $rc = 0 ] || echo "build-amiga.sh: failed (exit $rc) in stage: $STAGE"' EXIT
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$HERE/antiword.lock"
. "$HERE/scripts/aw-common.sh"
STOVE=${STOVE:-"$HOME/AmiCradle/stoves/os32-gcc16-open6"}
# outside the checkout: Cradle cleans it (git clean -ffdx) before every job
WORK="${WORK:-$HOME/.cache/gfamigaantiword/build}"; OUT="${OUT:-$WORK/out}"; JOBS=${JOBS:-8}
TC="$STOVE/prefix"; PATH="$TC/bin:$PATH"; export PATH
mkdir -p "$WORK/deps" "$OUT"; OUT=$(cd "$OUT" && pwd)
t0=$(date +%s)

# --- the PC tests first: the same sources, the AmigaOS lookups ---------------
STAGE="host tests"
if [ "${HOST_TESTS:-1}" != 0 ] && command -v "${HOST_CC:-cc}" > /dev/null 2>&1; then
    WORK="$WORK/host" sh "$HERE/tests/host-antiword.sh" > "$WORK/host-tests.log" 2>&1 || { tail -40 "$WORK/host-tests.log"; exit 1; }
    grep -E "checks passed" "$WORK/host-tests.log"
fi

# --- fpuauto: libfpuauto.a and its link specs ---------------------------------
STAGE="fpuauto"
FPD="$WORK/deps/fpuauto"
if [ "$(git -C "$FPD" rev-parse HEAD 2>/dev/null)" != "$FPA_COMMIT" ]; then
    rm -rf "$FPD"; mkdir -p "$FPD"; git -C "$FPD" init -q
    git -C "$FPD" config core.sparseCheckout true
    echo "/common/fpuauto/" > "$FPD/.git/info/sparse-checkout"
    git -C "$FPD" fetch -q --depth 1 --filter=blob:none "$FPA_REPO" "$FPA_COMMIT"
    git -C "$FPD" checkout -q FETCH_HEAD
fi
FA="$FPD/common/fpuauto"; FAL="$WORK/fpuauto"
if [ ! -f "$FAL/libfpuauto.a" ] || [ "$(cat "$FAL/.rev" 2>/dev/null)" != "$FPA_COMMIT" ]; then
    rm -rf "$FAL"; mkdir -p "$FAL/obj"
    m68k-amigaos-gcc -m68040 -DFPUAUTO_COMMON -c "$FA/fpuauto.S" -o "$FAL/obj/fa_common.o"
    for n in $(sed 's/^--wrap=//' "$FA/fpuauto.wraps"); do
        m68k-amigaos-gcc -m68040 -DR_$n -c "$FA/fpuauto.S" -o "$FAL/obj/fa_$n.o"
    done
    m68k-amigaos-ar rcs "$FAL/libfpuauto.a" "$FAL"/obj/fa_*.o
    echo "$FPA_COMMIT" > "$FAL/.rev"
fi

# --- Antiword at its pinned commit with patches/ ------------------------------
STAGE="source"
SRC="$WORK/antiword"
aw_source "$SRC"
LINK="m68k-amigaos-gcc -noixemul -m68040 -specs=$HERE/scripts/m68k-soft-m68040.specs -specs=$FA/fpuauto.specs -L$FAL"

# --- compile -------------------------------------------------------------------
STAGE="compile"
LATE=""
if m68k-amigaos-gcc -fno-late-combine-instructions -S -o /dev/null -x c /dev/null 2>/dev/null; then LATE="-fno-late-combine-instructions"; fi
# no loops turned into memset/memcpy calls (GCC 16), address 0 is memory;
# __amigaos picks upstream's AmigaOS settings and patches/0001's paths
CF="-noixemul -m68040 -O2 -fno-tree-loop-distribute-patterns -fno-delete-null-pointer-checks $LATE \
 -Werror=implicit-function-declaration -Werror=int-conversion -w \
 -D__amigaos -DNDEBUG -I$HERE/amiga -I$SRC \
 -DAW_AMIGA_VERSION=\\\"$AW_VERSION\\\" -DAW_AMIGA_DATE=\\\"$(date -u +%d.%m.%Y)\\\""
O="$WORK/obj"
# objects made against another Antiword or patch set go
[ "$(cat "$O/.src" 2>/dev/null)" = "$(cat "$SRC/.patched")" ] || { rm -rf "$O"; mkdir -p "$O"; cat "$SRC/.patched" > "$O/.src"; }
M="$O/Makefile"
{
    echo "CF = $CF"
    A=""
    for f in $AW_SRCS; do
        o="${f%.c}.o"; A="$A $o"
        printf '%s: %s\n\tm68k-amigaos-gcc $(CF) -MMD -c $< -o $@\n' "$o" "$SRC/$f"
    done
    for f in aw_path aw_amiga; do
        A="$A amiga_$f.o"
        printf 'amiga_%s.o: %s\n\tm68k-amigaos-gcc $(CF) -MMD -c $< -o $@\n' "$f" "$HERE/amiga/$f.c"
    done
    echo "OBJS =$A"
    echo "all: \$(OBJS)"
    echo "-include *.d"
} > "$M"
(cd "$O" && nice -n 19 make -k -j"$JOBS" all > make.log 2>&1) || { grep -E ': (fatal )?error' "$O/make.log" | head -40; grep -v "^m68k-amigaos-gcc " "$O/make.log" | tail -20; exit 1; }
echo "compile: $(( $(date +%s) - t0 )) s"

# --- link: soft-float specs, then fpuauto's -------------------------------------
STAGE="link"
# shellcheck disable=SC2046
$LINK -o "$O/antiword.debug" $(cd "$O" && for f in $(sed -n 's/^OBJS =//p' Makefile); do echo "$O/$f"; done) \
    -lm > "$O/link.log" 2>&1 || { head -60 "$O/link.log"; exit 1; }

# --- the GFOpenUp part: Parts/Antiword -------------------------------------------
STAGE="part"
P="$OUT/Parts/Antiword"; rm -rf "$P"; mkdir -p "$P/C" "$P/Utilities/Antiword" "$P/Docs/Antiword"
m68k-amigaos-strip -o "$P/C/antiword" "$O/antiword.debug"
for f in $(aw_resources "$SRC"); do cp "$SRC/Resources/$f" "$P/Utilities/Antiword/$f"; done
cp "$HERE/README.md" "$P/Docs/Antiword/ReadMe"
cp "$SRC/Docs/COPYING" "$P/Docs/Antiword/COPYING-Antiword"
cp "$SRC/Docs/antiword.man" "$P/Docs/Antiword/antiword.man"
cp "$SRC/Docs/FAQ" "$P/Docs/Antiword/FAQ"
sh "$HERE/scripts/write-part.sh" "$P" "$AW_VERSION"
# upstream's test document and the text it must give, for a lab (not in the part)
rm -rf "$OUT/tests"; mkdir -p "$OUT/tests"
cp "$SRC/Docs/testdoc.doc" "$HERE/tests/expected/testdoc.txt" "$OUT/tests/"
ls -l "$P/C/antiword"
echo "part: $(grep -c '^copy' "$P/Part") files, $(du -sk "$P" | cut -f1) KB"
echo "fpuauto: $(m68k-amigaos-nm "$O/antiword.debug" | grep -c ' T ___wrap_') wrapped routines"
echo "total: $(( $(date +%s) - t0 )) s"
