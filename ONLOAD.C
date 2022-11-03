/**
	ONLOAD.C - Patches loaded module files on-the-fly to add missing APIs
*/

#include "kex16.h"


typedef struct {
	WORD module;
	WORD ordinal;
	LPSTR procName;
	LPVOID procAddr;
} NEWPROC;

/**
	OLInit: Sets up LoadModule hook
*/
void NEAR PASCAL OLInit()
{
	
}
