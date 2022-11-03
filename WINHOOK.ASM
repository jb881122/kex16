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

cProc HookInit,<NEAR,PUBLIC,WIN,PASCAL>,<>
cBegin
	mov ax,word ptr [winMods].KERNEL

	push ax
	mov bx,offset ACDAName
	cCall GetProcAddress,<ax,ds,bx>
	mov cx,ax
	or cx,dx
	jz HI_noACDA

	mov word ptr AllocCStoDSAlias+2,dx
	mov word ptr AllocCStoDSAlias,ax
	jmp short HI_contACDA

HI_noACDA:
	push cs
	pop word ptr AllocCStoDSAlias+2
	mov word ptr AllocCStoDSAlias,offset CodeDataDummy

HI_contACDA:
	pop ax
	push ax
	mov bx,offset ADCAName
	cCall GetProcAddress,<ax,ds,bx>
	mov cx,ax
	or cx,dx
	jz HI_noADCA

	mov word ptr AllocDStoCSAlias+2,dx
	mov word ptr AllocDStoCSAlias,ax
	jmp short HI_contADCA

HI_noADCA:
	push cs
	pop word ptr AllocDStoCSAlias+2
	mov word ptr AllocDStoCSAlias,offset CodeDataDummy

HI_contADCA:
	pop ax
	mov bx,offset FSName
	cCall GetProcAddress,<ax,ds,bx>
	mov cx,ax
	or cx,dx
	jz HI_noFS

	mov word ptr FreeSelector+2,dx
	mov word ptr FreeSelector,ax
	jmp short HI_contFS

HI_noFS:
	push cs
	pop word ptr FreeSelector+2
	mov word ptr FreeSelector,offset CodeDataDummy

HI_contFS:
	mov ax,1
cEnd

;
; WORD FAR PASCAL HookProc(LPSTR, LPSTR, FARPROC, FARPROC FAR *);
;	LPSTR moduleName: The name of the library to hook
;	LPSTR procName: The name of the procedure to hook
;	FARPROC hookProc: The procedure to call instead
;	FARPROC FAR *oldProc: If not null, where to store the old function pointer
;	returns WORD: An ID to be used with other methods here
;		on failure: 0 is returned
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

HP_exitPop2:
	pop dx
	pop dx
	jmp short HP_exit

HP_foundLast:
	cCall ll_append,<bx>
	jmp short HP_foundCalled

HP_foundSpot:
	cCall ll_prepend,<bx>

HP_foundCalled:
	or ax,ax
	jz HP_exitPop2
	jmp short HP_spotCont

HP_noHooksYet:
	mov ax,size HOOKSTRUC
	cCall ll_create,<ax>
	or ax,ax
	jz HP_exitPop2
	mov HookList,ax
	push ax
	cCall AllocDStoCSAlias,<ds>
	mov DataToCode,ax
	pop ax

HP_spotCont:
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
; void FAR PASCAL UnhookProc(WORD);
;	WORD hookedProc: Return value of previous call to HookProc()
;
cProc UnhookProc,<NEAR,PUBLIC,WIN,PASCAL>,<si,di>
	parmW hookedProc
cBegin
	mov bx,HookList
	mov si,hookedProc
	cCall ll_getfirst,<bx>

UP_loop:
	or ax,ax
	jz UP_exit
	mov bx,ax
	cmp si,[bx].HookID
	je UP_found
	jb UP_exit
	cCall ll_getnext,<bx>
	jmp short UP_loop

UP_found:
	lea si,[bx].CodeBytes
	les di,dword ptr [bx].ProcOff
	errnz <ProcSegData-ProcOff-2>
	mov cx,patchSize
	rep movsb

	cCall ll_remove,<bx>
	mov HookList,ax

UP_exit:
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