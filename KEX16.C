/**
	KEX16.C - General initialization/dispatch functions
*/

#include "kex16.h"


FARPROC prevCWPHook = NULL;
FARPROC DWPWithData = NULL;
WORD hookedDWP = 0;
long newWndProcRet;
HANDLE winMods[NUM_MODS];
char wndClassName[8];

/* Make sure this is kept updated with the enum in KEX16.H */
char *winModNames[] = {
	"KERNEL",
	"GDI",
	"USER"
};

/**
	__new_DefWindowProc: Intercepts DefWndProc calls and changes the return value if directed
			by CWPHook
	Params:
		hWnd - the HWND of the WndProc that this was called from
		message - the window message associated with this call
		wParam - miscellaneous WORD providing more information
		lParam - miscellaneous DWORD providing more information
*/
long FAR PASCAL __new_DefWindowProc(hWnd, message, wParam, lParam)
HWND hWnd;
unsigned message;
WORD wParam;
LONG lParam;
{
	/* Unhook ourself */
	UnhookProc(hookedDWP);
	hookedDWP = 0;

	/* Return what CWPHook wanted */
	return newWndProcRet;
}

/**
	CWPHook: Called by Windows for every window message sent. Allows us to see when relevant
			messages are sent and act accordingly
	Params:
		nCode - only do anything if not negative
		wParam - miscellaneous WORD providing more information
		lParam - points to a CWPSTRUCT with window message info
*/
DWORD FAR PASCAL CWPHook(nCode, wParam, lParam)
int    nCode;
WORD   wParam;
DWORD  lParam;
{
	/* If a DefWindowProc hook was already made, get rid of it */
	if(hookedDWP) {
		UnhookProc(hookedDWP);
		hookedDWP = 0;
	}

	/* Are we looking at a valid message? */
	if (nCode >= 0 && lParam) {

		/* Yes, call the specialized code if it's anything we should do something with */
		if(((LPCWPSTRUCT)lParam)->message == LB_GETITEMDATA
				|| ((LPCWPSTRUCT)lParam)->message == LB_SETITEMDATA
				|| ((LPCWPSTRUCT)lParam)->message == WM_DESTROY) {

			/* See if it's a ListBox */
			GetClassName(((LPCWPSTRUCT)lParam)->hWnd, wndClassName, sizeof(wndClassName));
			if(!strcmp(wndClassName, "ListBox")) {

				/* Yep, call the ITEMDATA functions */
				switch(((LPCWPSTRUCT)lParam)->message) {
					case LB_GETITEMDATA:
						newWndProcRet = onLBGetItemData(
								((LPCWPSTRUCT)lParam)->hWnd,
								((LPCWPSTRUCT)lParam)->wParam);
						hookedDWP = HookProc(winMods[USER], "DefWindowProc", DWPWithData, NULL);
						break;
					case LB_SETITEMDATA:
						onLBSetItemData(
								((LPCWPSTRUCT)lParam)->hWnd,
								((LPCWPSTRUCT)lParam)->wParam,
								((LPCWPSTRUCT)lParam)->lParam);
						break;
					case WM_DESTROY:
						onWMDestroyLB(
								((LPCWPSTRUCT)lParam)->hWnd);
						break;
				}
			}
		}
	}

	/* Why is Windows successfully hooking and then returning NULL? */
	if(prevCWPHook) {

		/* There's a previous hook, call it */
		return DefHookProc(nCode, wParam, lParam, &prevCWPHook);
	} else {
		
		/* I don't know what to do here, just keep it from crashing for now */
		return 1;
	}
}

/**
	WinMain: Called on program start, handles initialization and cleanup
	Params:
		hInstance - the HANDLE of the current instance of the program
		hPrevInstance - the HANDLE of the previous instance (otherwise NULL)
		lpszCmdLine - zero-terminated command line for launching this program
		cmdShow - how a window by this program should be shown
*/
int NEAR PASCAL WinMain(hInstance, hPrevInstance, lpszCmdLine, cmdShow)
HANDLE hInstance, hPrevInstance;
LPSTR lpszCmdLine;
int cmdShow;
{
	int i;
	MSG msg;
	FARPROC CWPWithData = NULL;

	/* Default return value */
	msg.wParam = 0;

	/* Only allow this to be launched once */
    if(hPrevInstance)
        return FALSE;

	/* Load all needed module handles right away */
	for(i = 0; i < NUM_MODS; i++) {
		winMods[i] = GetModuleHandle(winModNames[i]);
		if(!winMods[i]) {
			return FALSE;
		}
	}

	/* Initialize any specialized code that needs it */
	OFInit();
	HookInit();

	/* Only set this stuff up if the OS doesn't support ITEMDATA in ListBoxes */
	if(!(OSFlags & HAS_LB_ITEMDATA)) {

		/* Make sure CWPHook can access global variables */
		CWPWithData = MakeProcInstance((FARPROC)CWPHook, hInstance);
		if(!CWPWithData) {
			goto getOut;
		}

		/* Make sure __new_DefWindowProc can access global variables */
		DWPWithData = MakeProcInstance((FARPROC)__new_DefWindowProc, hInstance);
		if(!DWPWithData) {
			goto getOut;
		}

		/* Set CWPHook as a hook for window messages */
		prevCWPHook = SetWindowsHook(WH_CALLWNDPROC, CWPWithData);
	}

    /* WM_QUIT message (if we ever get it) returns FALSE and terminates loop */
    while(GetMessage((LPMSG)&msg, NULL, 0, 0)) {
        TranslateMessage((LPMSG)&msg);
        DispatchMessage((LPMSG)&msg);
    }

	/* Clean up memory and exit the program */
getOut:

	/* Make sure specialized code can clean itself up */
	LBCleanup();

	/* Then clean up everything that this file's code may have done */
	if(hookedDWP) {
		UnhookProc(hookedDWP);
	}
	if(DWPWithData) {
		FreeProcInstance(DWPWithData);
	}
	if(CWPWithData) {
		UnhookWindowsHook(WH_CALLWNDPROC, CWPWithData);
		FreeProcInstance(CWPWithData);
	}

	/* Finally, exit the program */
    return msg.wParam;
}
