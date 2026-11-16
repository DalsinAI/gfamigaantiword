# GFAmigaAntiword

Antiword 0.37, the MS Word document reader, for GFOS (AmigaOS 3.2.3 with
GFOpenUp) on a 68040 or 68060, installed as a GFOpenUp part:
`C:antiword`. It reads Word 2, 6, 7, 97, 2000, 2002 and 2003 `.doc`
files and writes them as plain text, PostScript or PDF.

    antiword Work:letters/offer.doc
    antiword -p a4 Work:letters/offer.doc >PRT:
    antiword -a a4 Work:letters/offer.doc >RAM:offer.pdf

Status: built for the PC from the same patched sources with the AmigaOS
settings and passing the tests below; the Amiga build is made by the
stove, not yet run in a lab.

## What you need

- GFOS: AmigaOS 3.2 with GFOpenUp, a 68040 or 68060. Soft float: the FPU
  is used when there is one (fpuauto), so an LC040 runs it too.
- Nothing else.

Install with `GFOpenUpTool INSTALL Parts/Antiword`. The manual is
`SYS:Docs/Antiword/antiword.man`.

## On AmigaOS

- The character mapping files (`-m`, e.g. `-m cp850.txt`) and the
  PostScript font names live in `SYS:Utilities/Antiword`. A drawer named
  by the `ANTIWORDHOME` variable is tried first, then `.antiword` in the
  `HOME` drawer when `HOME` is set (`Work:` gives `Work:.antiword`).
- With no `LANG`, text comes out as ISO-8859-1, the Amiga's own
  character set.
- 64 KB of stack is set in the program, so the Shell's 4 KB is enough.

## Building

    STOVE=~/AmiCradle/stoves/os32-gcc16-open6 OUT=out sh build-amiga.sh

or in Cradle, stove_build with the os32-gcc16-open6 stove, target `.`.
Antiword and fpuauto are fetched at the commits `antiword.lock` pins
(Antiword from grobian/antiword, which keeps the original sources and
the fixes made since). `OUT` gets `Parts/Antiword` (the part) and
`tests/` (upstream's `testdoc.doc` and the text it must give, for a lab).

## Tests

`make -C tests test` on a PC: the Part file, the AmigaDOS path joining
(`amiga/aw_path.c`), then `tests/host-antiword.sh`, which builds
Antiword twice, as upstream and from the patched sources with
`-D__amigaos` (the AmigaOS code paths), and checks that:

- text, PostScript and PDF of upstream's `Docs/testdoc.doc` are the same
  from both, and the text is `tests/expected/testdoc.txt`,
- with no `HOME`, nothing is printed on stderr,
- the files come from `SYS:Utilities/Antiword`, from `ANTIWORDHOME`
  first, and from `Work:.antiword` with `HOME` set to `Work:`,
- `-m cp850.txt` finds its mapping file,
- with no resources there is one message naming `SYS:Utilities/Antiword`.

## What was changed

- `patches/0001`: under `__amigaos`, the global drawer is
  `SYS:Utilities/Antiword` (upstream's old AmigaOS setting was
  `SYS:.antiword`); the mapping file and font name lookups join paths
  the AmigaDOS way (no `/` after a volume name); no `HOME` is not an
  error.
- `amiga/aw_path.c`: that join, plain C so the PC tests build it.
- `amiga/aw_amiga.c`: stack and `$VER`.

Antiword is GPL-2.0 (`SYS:Docs/Antiword/COPYING-Antiword`); the files
here are MIT.

Designed, tested and delivered by The AmiCradle Team.
