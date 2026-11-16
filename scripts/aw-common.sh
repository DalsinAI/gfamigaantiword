# What build-amiga.sh (the stove) and tests/host-antiword.sh (the PC)
# share: Antiword's sources and fetching them with patches/ applied.
# Sourced; needs HERE (the repo) and antiword.lock's settings.
# MIT, Copyright (c) 2026 AmiCradle Team.

# the program's files, as upstream's Makefile.Linux (OBJS)
AW_SRCS="main_u.c asc85enc.c blocklist.c chartrans.c datalist.c depot.c
 dib2eps.c doclist.c fail.c finddata.c findtext.c fmt_text.c fontlist.c
 fonts.c fonts_u.c hdrftrlist.c imgexam.c imgtrans.c jpeg2eps.c
 listlist.c misc.c notes.c options.c out2window.c output.c pdf.c
 pictlist.c png2eps.c postscript.c prop0.c prop2.c prop6.c prop8.c
 properties.c propmod.c rowlist.c sectlist.c stylelist.c stylesheet.c
 summary.c tabstop.c text.c unix.c utf8.c word2text.c worddos.c
 wordlib.c wordmac.c wordole.c wordwin.c xmalloc.c xml.c"

# a repository at one commit, fetched once: fetch_at DIR URL COMMIT
fetch_at() {
    if [ "$(git -C "$1" rev-parse HEAD 2>/dev/null)" != "$3" ]; then
        rm -rf "${1:?}"; mkdir -p "$1"
        git -C "$1" init -q
        git -C "$1" fetch -q --depth 1 "$2" "$3"
        git -C "$1" checkout -q FETCH_HEAD
        [ "$(git -C "$1" rev-parse HEAD)" = "$3" ] || { echo "$1: commit mismatch"; exit 1; }
    fi
}

# Antiword at AW_COMMIT with patches/ applied, into $1 (redone when
# either changes); fontinfo.h is upstream's Unix-only one, as its Makefile
aw_source() {
    PSUM=$(cat "$HERE"/patches/*.patch | sha256sum | cut -c1-16)
    if [ "$(cat "$1/.patched" 2>/dev/null)" != "$AW_COMMIT-$PSUM" ]; then
        rm -rf "$1"
        fetch_at "$1" "$AW_GIT" "$AW_COMMIT"
        for p in "$HERE"/patches/*.patch; do
            patch -s -d "$1" -p1 < "$p" || { echo "patch failed: $p"; exit 1; }
        done
        cp "$1/Unix-only/fontinfo.h" "$1/fontinfo.h"
        echo "$AW_COMMIT-$PSUM" > "$1/.patched"
    fi
}

# the files the part puts in SYS:Utilities/Antiword: every mapping file
# and the PostScript font names (upstream's global_install list)
aw_resources() {
    (cd "$1/Resources" && ls ./*.txt fontnames | sed 's#^\./##' | LC_ALL=C sort)
}
