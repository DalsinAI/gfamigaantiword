#!/bin/sh
# Writes the Part file GFOpenUpTool INSTALL reads (gfopenup src/openuptool.c)
# for the part drawer the build made: C/antiword to C:antiword,
# Utilities/Antiword/ (the mapping files and font names) to
# SYS:Utilities/Antiword/, Docs/Antiword/ to SYS:Docs/Antiword/.
#   write-part.sh <part drawer> <version>
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu
P=$1; V=$2
{
    echo "part Antiword $V"
    echo "; Antiword: MS Word (2 to 2003) documents to text, PostScript or PDF (C:antiword)"
    echo "needs 68040"
    (cd "$P" && find C Utilities Docs -type f | LC_ALL=C sort) | while read -r f; do
        echo "copy \"$f\" \"SYS:$f\""
    done
} > "$P/Part"
