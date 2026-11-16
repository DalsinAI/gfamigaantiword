/* Antiword on GFOS: the $VER string and a stack that takes long tables
 * and deep lists (the Shell gives 4 KB).
 * MIT, Copyright (c) 2026 AmiCradle Team. */
unsigned long __stack = 64 * 1024;
static const char version[] __attribute__((used)) =
	"$VER: antiword " AW_AMIGA_VERSION " (" AW_AMIGA_DATE ") GFOS";
