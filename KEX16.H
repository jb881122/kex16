;/*
if 0 ;*/
/**
	KEX16.H - Common definitions
*/

#include "windows.h"
/*
endif
include cmacros.inc
if 0 ;*/


/* Begin SDK compatibility defs */

#ifndef NPVOID
typedef void NEAR *NPVOID;
#endif
#ifndef LPVOID
typedef void FAR *LPVOID;
#endif
#ifndef LB_GETITEMDATA
#define LB_GETITEMDATA (WM_USER+26)
#endif
#ifndef LB_SETITEMDATA
#define LB_SETITEMDATA (WM_USER+27)
#endif
typedef struct {
	DWORD     lParam;
	WORD      wParam;
	WORD      message;
	HWND      hWnd;
} CWPSTRUCT;
typedef CWPSTRUCT FAR *LPCWPSTRUCT;

/* End SDK compatibility defs */


/* Begin WinAPI hooker defs */

void NEAR PASCAL HookInit(void);
WORD NEAR PASCAL HookProc(HANDLE, LPSTR, FARPROC, FARPROC FAR *);
void NEAR PASCAL UnhookProc(WORD);

/* End WinAPI hooker defs */


/* Begin linked list handler defs */

/*
endif
ifndef IS_LLIST
externNP ll_create		;*/ NPVOID NEAR PASCAL ll_create(BYTE); /*
externNP ll_append		;*/ NPVOID NEAR PASCAL ll_append(NPVOID); /*
externNP ll_prepend		;*/ NPVOID NEAR PASCAL ll_prepend(NPVOID); /*
externNP ll_remove		;*/ NPVOID NEAR PASCAL ll_remove(NPVOID); /*
externNP ll_getfirst	;*/ NPVOID NEAR PASCAL ll_getfirst(NPVOID); /*
externNP ll_getnext		;*/ NPVOID NEAR PASCAL ll_getnext(NPVOID); /*
endif
if 0 ;*/

/* End linked list handler defs */


/* Begin OS feature detection defs */

/*
endif

; If this is updated, remember to update the C list below!
HAS_LB_ITEMDATA equ (1 shl 0)

externD _OSFlags		;*/ extern DWORD OSFlags; /*
OSFlags equ _OSFlags

if 0 ;*/

/* If this is updated, remember to update the ASM list above! */
#define HAS_LB_ITEMDATA (1 << 0)

void NEAR PASCAL OFInit(void);

/* End OS feature detection defs */


/* Begin LB_*ITEMDATA-specific defs */

long NEAR PASCAL onLBGetItemData(HWND, WORD);
void NEAR PASCAL onLBSetItemData(HWND, WORD, LONG);
void NEAR PASCAL onWMDestroyLB(HWND);
void NEAR PASCAL LBCleanup(void);

/* End LB_*ITEMDATA-specific defs */


/* Begin general initialization/dispatch defs */

/* Make sure this is kept updated with the string list in KEX16.C */
/*
endif
MODNAME struc			;*/ typedef enum { /*
	KERNEL dw ?			;*/ 	KERNEL, /*
	GDI dw ?			;*/ 	GDI, /*
	USER dw ?			;*/ 	USER, /*
						;*/ 	NUM_MODS /*
MODNAME ends			;*/ } MODNAME; /*
NUM_MODS equ ((size MODNAME) shr 1)

externNP _winMods		;*/ extern HANDLE winMods[NUM_MODS]; /*
winMods equ _winMods
if 0 ;*/

long FAR PASCAL __new_DefWindowProc(HWND, unsigned, WORD, LONG);
typedef long (FAR PASCAL *DWPPROC)(HWND, unsigned, WORD, LONG);

DWORD FAR PASCAL CWPHook(int, WORD, DWORD);

BOOL NEAR PASCAL onMessage(HWND, unsigned, WORD, LONG, long FAR *);
int NEAR PASCAL WinMain(HANDLE, HANDLE, LPSTR, int);

/* End general initialization/dispatch defs */

/*
endif ;*/
