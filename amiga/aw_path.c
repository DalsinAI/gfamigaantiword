/* AmigaDOS path joining for Antiword's resource lookups: a '/' goes
 * between the parts only when the first does not already end in ':' or
 * '/' ("Work:" + "x" is "Work:x", "Work:a" + "x" is "Work:a/x"; a '/'
 * after a volume name would mean the parent of its root).
 * Plain C, no AmigaOS headers, so the PC tests build it too.
 * MIT, Copyright (c) 2026 AmiCradle Team. */
#include <stddef.h>
#include <string.h>
#include "aw_path.h"

int bAmigaJoin(char *szOut, size_t tSize, const char *szDir, const char *szName)
{
	size_t	tDir, tName, tSep;

	if (szOut == NULL || tSize == 0 || szDir == NULL || szName == NULL) {
		return 0;
	}
	tDir = strlen(szDir);
	tName = strlen(szName);
	tSep = (tDir == 0 || szDir[tDir - 1] == ':' || szDir[tDir - 1] == '/') ? 0 : 1;
	if (tDir + tSep + tName + 1 > tSize) {
		szOut[0] = '\0';
		return 0;
	}
	memmove(szOut, szDir, tDir);
	if (tSep) {
		szOut[tDir] = '/';
	}
	memcpy(szOut + tDir + tSep, szName, tName + 1);
	return 1;
}
