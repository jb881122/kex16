;
;	WINHOOK.ASM - Changes the behavior of existing Win16 API functions
;


IS_WINHOOK equ 1
include kex16.h

externFP GetModuleHandle
externFP GetProcAddress

patchSize			equ 5
I_JMP_FAR_PTR16		equ 0EAh
I_CALL_FAR_PTR16	equ 09Ah

HOOKSTRUC struc
	HookID		dw ?

	FarCall		db ?
	COPOff		dw ?
	COPSeg		dw ?

	ProcOff		dw ?
	ProcSegData	dw ?
	ProcSegCode	dw ?

	CodeBytes	db patchSize dup(?)

; The following are not initialized until an OldProc call is made
	ReturnOff	dw ?
	ReturnSeg	dw ?
	ReturnSI	dw ?
	ReturnDI	dw ?
HOOKSTRUC ends

sBegin Data
assumes cs,Data

HookList			dw 0
DataToCode			dw ?
AllocCStoDSAlias	dd ?
AllocDStoCSAlias	dd ?
FreeSelector		dd ?
ACDAName			db "AllocCStoDSAlias",0
ADCAName			db "AllocDStoCSAlias",0
FSName				db "FreeSelector",0

sEnd Data

sBegin Code
assumes cs,Code
assumes ds,Data

;
;	HookInit: Determines if several protected mode-specific procedures exist and switches them for
;			a dummy function if not
;
cProc HookInit,<NEAR,PUBLIC,WIN,PASCAL>,<>
cBegin
	; Get the KERNEL module handle
	mov ax,word ptr [winMods].KERNEL

	; Does AllocCStoDSAlias exist here?
	push ax
	mov bx,offset ACDAName
	cCall GetProcAddress,<ax,ds,bx>
	mov cx,ax
	or cx,dx
	jz HI_noACDA

	; Yes, copy the proc. address where we will reference it
	mov word ptr AllocCStoDSAlias+2,dx
	mov word ptr AllocCStoDSAlias,ax
	jmp short HI_contACDA

	; No, just use our dummy function instead
HI_noACDA:
	push cs
	pop word ptr AllocCStoDSAlias+2
	mov word ptr AllocCStoDSAlias,offset CodeDataDummy

	; Does AllocDStoCSAlias exist here?
HI_contACDA:
	pop ax
	push ax
	mov bx,offset ADCAName
	cCall GetProcAddress,<ax,ds,bx>
	mov cx,ax
	or cx,dx
	jz HI_noADCA

	; Yes, copy the proc. address where we will reference it
	mov word ptr AllocDStoCSAlias+2,dx
	mov word ptr AllocDStoCSAlias,ax
	jmp short HI_contADCA

	; No, just use our dummy function instead
HI_noADCA:
	push cs
	pop word ptr AllocDStoCSAlias+2
	mov word ptr AllocDStoCSAlias,offset CodeDataDummy

	; Does FreeSelector exist here?
HI_contADCA:
	pop ax
	mov bx,offset FSName
	cCall GetProcAddress,<ax,ds,bx>
	mov cx,ax
	or cx,dx
	jz HI_noFS

	; Yes, copy the proc. address where we will reference it
	mov word ptr FreeSelector+2,dx
	mov word ptr FreeSelector,ax
	jmp short HI_contFS

	; No, just use our dummy function instead
HI_noFS:
	push cs
	pop word ptr FreeSelector+2
	mov word ptr FreeSelector,offset CodeDataDummy

	; Allocate the selector allowing us to execute code from the data segment
HI_contFS:
	cCall AllocDStoCSAlias,<ds>
	mov DataToCode,ax
cEnd

;
;	HookProc: Hooks a WinAPI procedure to call the specified function instead
;	Params:
;		module - the handle for the module to hook
;		procName - pointer to the name of the procedure to hook
;		hookProc - pointer to the procedure to call instead
;		oldProc - if not NULL, where to store the old function pointer
;	Returns: An ID to be used with UnhookProc, 0 on failure
;
cProc HookProc,<NEAR,PUBLIC,WIN,PASCAL>,<si,di,ds>
	parmW module
	parmD procName
	parmD hookProc
	parmD oldProc
cBegin
	; Get the address of the function code
	cCall GetProcAddress,<module,procName>
	mov cx,ax
	or cx,dx
	;jz HP_exit
	jnz HP_gotProcAddr
	jmp HP_exit
HP_gotProcAddr:
	push dx
	push ax

	; Now start allocating space for the hook
	mov si,1
	mov bx,HookList
	or bx,bx
	jz HP_noHooksYet

	; Other hooks exist, find first available hook ID
	cCall ll_getfirst,<bx>
	mov bx,ax
HP_firstSpotLoop:
	cmp si,[bx].HookID
	jne HP_foundSpot
	inc si
	cCall ll_getnext,<bx>
	or ax,ax
	jz HP_foundLast
	mov bx,ax
	jmp short HP_firstSpotLoop

	; In case something fails while the proc. address is still on the stack
HP_exitPop2:
	pop dx
	pop dx
	jmp short HP_exit

	; First available ID is after the end, append to the list
HP_foundLast:
	cCall ll_append,<bx>
	jmp short HP_spotCont

	; Otherwise, we're already past that available ID, so prepend to the later hook
HP_foundSpot:
	cCall ll_prepend,<bx>
	jmp short HP_spotCont

	; No list of hooks right now, create a new one
HP_noHooksYet:
	mov ax,size HOOKSTRUC
	cCall ll_create,<ax>
	mov HookList,ax

	; Success creating the list element?
HP_spotCont:
	or ax,ax
	jz HP_exitPop2
	mov bx,ax

	; Start populating the HOOKSTRUC object we have
	mov [bx].HookID,si
	pop [bx].ProcOff
	pop ax
	mov [bx].ProcSegCode,ax
	push bx
	cCall AllocCStoDSAlias,<ax>
	pop bx
	mov [bx].ProcSegData,ax
	mov [bx].FarCall,I_CALL_FAR_PTR16
	push cs
	pop [bx].COPSeg
	mov [bx].COPOff,offset CallOldProc

	; Copy the original code to the HOOKSTRUC
	push ds
	pop es
	assumes es,Data
	lea di,[bx].CodeBytes
	lds si,dword ptr [bx].ProcOff
	assumes ds,nothing
	errnz <ProcSegData-ProcOff-2>
	push si
	mov cx,patchSize
	rep movsb

	; Store the patch code to the procedure location
	pop di
	push ds
	push es
	pop ds
	assumes ds,Data
	pop es
	assumes es,nothing
	mov al,I_JMP_FAR_PTR16
	stosb
	mov ax,off_hookProc
	stosw
	mov ax,seg_hookProc
	stosw

	; Fill oldProc w/ code address in HOOKSTRUC if needed
	les di,oldProc
	mov ax,es
	or ax,di
	jz HP_exitSuccess
	mov ax,DataToCode
	stosw
	lea ax,[bx].FarCall
	stosw

HP_exitSuccess:
	mov ax,[bx].HookID

HP_exit:
cEnd

;
;	UnhookProc: Restores a WinAPI procedure to its original state
;	Params:
;		hookedProc - Return value of previous call to HookProc
;
cProc UnhookProc,<NEAR,PUBLIC,WIN,PASCAL>,<si,di>
	parmW hookedProc
cBegin
	; Get the first hook in the list
	mov bx,HookList
	mov si,hookedProc
	cCall ll_getfirst,<bx>

	; Iterate through the list until we find the hook or pass it (list is sorted)
UP_loop:
	or ax,ax
	jz UP_exit
	mov bx,ax
	cmp si,[bx].HookID
	je UP_found
	jb UP_exit
	cCall ll_getnext,<bx>
	jmp short UP_loop

	; Restore the original bytes at the procedure location
UP_found:
	lea si,[bx].CodeBytes
	les di,dword ptr [bx].ProcOff
	errnz <ProcSegData-ProcOff-2>
	mov cx,patchSize
	rep movsb

	; Free the selector allowing us to patch that code
	push bx
	cCall FreeSelector,<[bx].ProcSegData>
	pop bx

	; Get rid of the hook item from the list
	cCall ll_remove,<bx>
	mov HookList,ax

UP_exit:
cEnd

;
;	HookCleanup: Unhooks all hooks and frees anything allocated
;
cProc HookCleanup,<NEAR,PUBLIC,WIN,PASCAL>,<>
cBegin
	; Free the selector that allowed us to execute code in the data segment
	cCall FreeSelector,<DataToCode>

	; Unhook any procedures that were left hooked
HC_loop:
	mov bx,HookList
	or bx,bx
	jz HC_exit
	cCall UnhookProc,<[bx].HookID>
	jmp short HC_loop

HC_exit:
cEnd

;
;	CodeDataDummy: Replaces AllocDStoCSAlias, AllocCStoDSAlias, and FreeSelector on platforms
;			(e.g. Win2.x) that only run in real or V86 mode
;	Params:
;		segToReturn - any segment
;	Returns: The segment that was passed to it
;
cProc CodeDataDummy,<FAR,PUBLIC,WIN,PASCAL>,<>
	parmW segToReturn
cBegin
	; No distinction between code & data segments here, so just return what we got
	mov ax,segToReturn
cEnd

;
;	CallOldProc: Switches back patched bytes to the original ones, calls the old procedure, and
;			re-patches it (not meant to be called directly)
;
CallOldProc	proc far

	; Since we used far call to get here, there is a return address on the
	;  stack with an offset two bytes after COPSeg in the HOOKSTRUC
	pop bx
	pop dx
	sub bx,COPSeg+2

	; Now: DS:BX -> current HOOKSTRUC
	; Save SI, DI
	mov [bx].ReturnSI,si
	mov [bx].ReturnDI,di

	; Swap OldProc bytes for ours
	les di,dword ptr [bx].ProcOff
	errnz <ProcSegData-ProcOff-2>
	lea si,[bx].CodeBytes
	mov cx,patchSize
	cld

COPLoop:
	mov al,es:[di]
	xchg al,[si]
	stosb
	inc si
	loop COPLoop

	; Do something with the other return address now
	pop ax
	mov [bx].ReturnOff,ax
	pop ax
	mov [bx].ReturnSeg,ax

	; Give the old proc our own return address
	push cs
	mov ax,offset COPAfterCall
	push ax

	; And call it?
	push [bx].ProcSegCode
	push [bx].ProcOff

	; WAIT... BX isn't preserved! SI & DI should be, though
	mov si,bx

	; NOW call it
	ret ;"proc far" makes this a retf

COPAfterCall:
	; Now, arguments should be popped off the stack, so we can simply
	;  swap the bytes back and far return w/ no extra bytes.
	; Just don't mess with AX or DX (the return value) when doing it
	; We're basically at square one w/ registers except SI, DI, & DS
	mov bx,si
	les di,dword ptr [bx].ProcOff
	errnz <ProcSegData-ProcOff-2>
	lea si,[bx].CodeBytes
	mov cx,patchSize
	push ax
	cld

COPLoopRev:
	mov al,es:[di]
	xchg al,[si]
	stosb
	inc si
	loop COPLoopRev

	pop ax ; Preserved LOWORD of return value (we didn't use DX)

	; Restore preserved registers
	mov si,[bx].ReturnSI
	mov di,[bx].ReturnDI

	; Now get out of here
	push [bx].ReturnSeg
	push [bx].ReturnOff
	ret ;"proc far" makes this a retf
CallOldProc	endp

sEnd Code


END
