;
;	LLIST.ASM - Linked list handler
;


IS_LLIST equ 1
include kex16.h

externFP LocalAlloc
externFP LocalFree
LMEM_FIXED equ 0

LINKEDLIST struc
	DataSize	db ?
	Previous	dw ?
	Next		dw ?
	;Data goes here, is variable-size
LINKEDLIST ends
LData equ (size LINKEDLIST)

sBegin Code
assumes cs,Code

;
;	ll_create: Creates a new linked list for items of the specified size
;	Params:
;		dataLength - the size in bytes of each item
;	Returns: Pointer to the new item data, NULL if failed
;
cProc ll_create,<NEAR,PUBLIC,WIN,PASCAL>,<>
	parmB dataLength
cBegin
	; Attempt to allocate enough bytes to begin this list
	xor bx,bx
	errnz <LMEM_FIXED>
	mov al,dataLength
	xor ah,ah
	add ax,size LINKEDLIST
	cCall LocalAlloc,<bx,ax>

	; Were we successful? Return NULL if not
	or ax,ax
	jz llc_exit

	; Get the address into an indexable spot
	mov bx,ax

	; Initialize the linked list header
	mov al,dataLength
	mov [bx].DataSize,al
	xor ax,ax
	mov [bx].Previous,ax
	mov [bx].Next,ax

	; Return the address of the data
	lea ax,[bx].LData
llc_exit:
cEnd

;
;	ll_append: Adds an item to the list after the provided item
;	Params:
;		existing - the item to add a new item after
;	Returns: Pointer to the new item data, NULL if failed
;
cProc ll_append,<NEAR,PUBLIC,WIN,PASCAL>,<si>
	parmW existing
cBegin
	; Attempt to allocate same # of bytes as existing item
	xor bx,bx
	errnz <LMEM_FIXED>
	mov si,existing
	sub si,size LINKEDLIST
	mov al,[si].DataSize
	xor ah,ah
	add ax,size LINKEDLIST
	cCall LocalAlloc,<bx,ax>

	; Were we successful? Return NULL if not
	or ax,ax
	jz lla_exit

	; Get the address into an indexable spot
	mov bx,ax

	; Initialize the linked list header
	mov al,[si].DataSize
	mov [bx].DataSize,al
	mov ax,[si].Next
	mov [bx].Next,ax
	mov [bx].Previous,si

	; Update the previous and next items
	mov [si].Next,bx
	or ax,ax
	jz lla_nonext
	mov si,ax
	mov [si].Previous,bx
lla_nonext:

	; Return the address of the data
	lea ax,[bx].LData
lla_exit:
cEnd

;
;	ll_prepend: Adds an item to the list before the provided item
;	Params:
;		existing - the item to add a new item before
;	Returns: Pointer to the new item data, NULL if failed
;
cProc ll_prepend,<NEAR,PUBLIC,WIN,PASCAL>,<si>
	parmW existing
cBegin
	; Attempt to allocate same # of bytes as existing item
	xor bx,bx
	errnz <LMEM_FIXED>
	mov si,existing
	sub si,size LINKEDLIST
	mov al,[si].DataSize
	xor ah,ah
	add ax,size LINKEDLIST
	cCall LocalAlloc,<bx,ax>

	; Were we successful? Return NULL if not
	or ax,ax
	jz llp_exit

	; Get the address into an indexable spot
	mov bx,ax

	; Initialize the linked list header
	mov al,[si].DataSize
	mov [bx].DataSize,al
	mov ax,[si].Previous
	mov [bx].Previous,ax
	mov [bx].Next,si

	; Update the previous and next items
	mov [si].Previous,bx
	or ax,ax
	jz llp_noprev
	mov si,ax
	mov [si].Next,bx
llp_noprev:

	; Return the address of the data
	lea ax,[bx].LData
llp_exit:
cEnd

;
;	ll_remove: Deletes an item from the list
;	Params:
;		itemToRemove - the item to remove
;	Returns: Pointer to the next item's data, the last item if at end, and NULL for empty list
;
cProc ll_remove,<NEAR,PUBLIC,WIN,PASCAL>,<si>
	parmW itemToRemove
cBegin
	; Get the previous and next items (if any)
	mov bx,itemToRemove
	sub bx,size LINKEDLIST
	mov si,[bx].Previous
	mov ax,[bx].Next

	; Update the references
	; Also puts unadjusted return value into DX
	mov dx,si
	or si,si
	jz llr_noprev
	mov [si].Next,ax
llr_noprev:
	xchg ax,si
	or si,si
	jz llr_nonext
	mov [si].Previous,ax
	mov dx,si
llr_nonext:

	; Save our return value
	push dx

	; Remove the item
	cCall LocalFree,<bx>

	; Adjust and return the saved value
	pop ax
	or ax,ax
	jz llr_exit
	add ax,size LINKEDLIST
llr_exit:
cEnd

;
;	ll_getfirst: Finds the beginning of the list
;	Params:
;		itemInList - any item within the list
;	Returns: Pointer to the data of the first item, NULL if itemInList == NULL
;
cProc ll_getfirst,<NEAR,PUBLIC,WIN,PASCAL>,<>
	parmW itemInList
cBegin
	; Get the current item
	mov ax,itemInList
	or ax,ax
	jz llgf_exit
	mov cx,ax
	sub cx,size LINKEDLIST

	; Keep getting the previous item until we hit the first one
llgf_loop:
	mov bx,cx
	mov cx,[bx].Previous
	or cx,cx
	jnz llgf_loop

	; Return the address of the data
	lea ax,[bx].LData
llgf_exit:
cEnd

;
;	ll_getnext: Finds the next item in the list
;	Params:
;		itemInList - an item within the list
;	Returns: Pointer to the data of the next item, NULL if at end
;
cProc ll_getnext,<NEAR,PUBLIC,WIN,PASCAL>,<>
	parmW itemInList
cBegin
	; Get the current item
	mov bx,itemInList
	sub bx,size LINKEDLIST

	; Get the next item
	mov ax,[bx].Next

	; Return the address of the data (if it exists)
	or ax,ax
	jz llgn_exit
	add ax,size LINKEDLIST
llgn_exit:
cEnd

sEnd Code


END
