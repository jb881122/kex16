/**
	OSFLAGS.C - Feature detection of the underlying OS
*/

#include "kex16.h"


DWORD OSFlags;
DWORD FlagTested;

/**
	OFInit: Called on program start, detects OS features and saves them to a variable
*/
void NEAR PASCAL OFInit()
{
	FARPROC testProcAddr;

	/* Start w/ no features tested */
	FlagTested = 0;

	/* OR the bit if feature is present, do nothing otherwise */
	OSFlags = 0;


	/* Begin ListBox ITEMDATA presence test */

	/* Does LBoxCtlWndProc exist (added early 1985, removed in 3.1 development)? */
	testProcAddr = GetProcAddress(winMods[USER], "LBoxCtlWndProc");

	/* If not (assuming it's newer) or we can see that ITEMDATA exists... */
	if(!testProcAddr ||
			(*testProcAddr)(GetTopWindow((HWND)NULL), LB_GETITEMDATA, 0, 0L) == -1) {

		/* Yes, this feature exists */
		OSFlags |= HAS_LB_ITEMDATA;
	}

	/* This feature is now tested */
	FlagTested |= HAS_LB_ITEMDATA;

	/* End ListBox ITEMDATA presence test */


}
