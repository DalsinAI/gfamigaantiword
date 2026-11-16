/* PC test for amiga/aw_path.c. MIT, Copyright (c) 2026 AmiCradle Team. */
#include <stdio.h>
#include <string.h>
#include "aw_path.h"

static int fails;
static void check(const char *dir, const char *name, size_t size, int ok, const char *want)
{
	char buf[64];
	int r = bAmigaJoin(buf, size, dir, name);
	if (r != ok || (ok && strcmp(buf, want) != 0) || (!ok && buf[0] != '\0')) {
		printf("FAIL: \"%s\" + \"%s\" (%zu): got %d \"%s\", want %d \"%s\"\n",
		       dir, name, size, r, buf, ok, want ? want : "");
		fails++;
	}
}

int main(void)
{
	check("SYS:Utilities/Antiword", "fontnames", 64, 1, "SYS:Utilities/Antiword/fontnames");
	check("Work:", ".antiword", 64, 1, "Work:.antiword");
	check("Work:home/", ".antiword", 64, 1, "Work:home/.antiword");
	check("Work:home", ".antiword", 64, 1, "Work:home/.antiword");
	check("ENV:Antiword", "8859-1.txt", 64, 1, "ENV:Antiword/8859-1.txt");
	check("", "cp437.txt", 64, 1, "cp437.txt");
	check("RAM:", "x", 64, 1, "RAM:x");
	/* exactly fits: "A:b/c" + NUL = 6 */
	check("A:b", "c", 6, 1, "A:b/c");
	check("A:b", "c", 5, 0, NULL);
	check("A:", "bc", 5, 1, "A:bc");
	check("A:", "bcd", 5, 0, NULL);
	if (bAmigaJoin(NULL, 8, "a", "b") || bAmigaJoin((char[8]){0}, 8, NULL, "b")) {
		printf("FAIL: NULL accepted\n");
		fails++;
	}
	if (fails == 0) printf("AmigaDOS paths: all checks passed\n");
	return fails != 0;
}
