;**********************************************************************
;*****
;*****              
;*****
;**********************************************************************

        MASM
        .MODEL TPASCAL
        .386

        LOCALS @@


        INCLUDE STRUCTS.ASM
        INCLUDE MACROS.ASM


; Call VCPI function no. 'fno'.

vcpi    MACRO   fno
        mov     al,&fno
        mov     ah,0deh
        int     67h
        ENDM


        .DATA

        EXTRN   v86     : v86def 


        .CODE
;**********************************************************************
;* Proc. Name     : PtrToHuge
;* Function       : 
;**********************************************************************
;FUNCTION PtrToHuge(P: Pointer): HugePtr; EXTERNAL;

PtrToHuge  PROC FAR P: DWORD;
           PUBLIC PtrToHuge

        xor     ebx,ebx
        les     bx,P
        segadr  es
        add     eax,ebx
        mov     edx,eax
        shr     edx,16
        ret

PtrToHuge  ENDP



;**********************************************************************
;* Proc. Name     : VCPIAvail
;* Function       : Returns TRUE if VCPI server is present.
;**********************************************************************
; FUNCTION VCPIAvail: BOOLEAN;

VCPIAvail  PROC FAR
           PUBLIC VCPIAvail

        xor     cx,cx
        mov     di,12H       ; DosBox weirdness
        vcpi    0
        or      ah,ah
        jnz     @@1
        mov     al,1
        ret
@@1:    xor     al,al
        ret

VCPIAvail  ENDP

;**********************************************************************
;* Proc. Name     : GetVCPI
;* Function       : Get VCPI Protected Mode Interface
;**********************************************************************
;FUNCTION GetVCPI(PageTb,GDTEntry: Pointer;
;                 VAR EntryPoint: LONGINT; VAR FreeOffs: WORD): BOOLEAN; EXTERNAL;


GetVCPI PROC FAR PageTb: DWORD, GDTEntry: DWORD, EntryPoint: DWORD, FreeOffs: DWORD
        PUBLIC GetVCPI

        push    ds
        les     di,pagetb
        lds     si,GDTEntry
        vcpi    01h
        pop     ds
        mov     ecx,ebx      ; entrypoint to eax   
        or      ah,ah
        mov     al,0
        jnz     @@1
        les     bx,FreeOffs
        mov     es:[bx],di   ; save FreeOffs
        les     di,EntryPoint
        mov     es:[di],ecx
        mov     al,1
@@1:    ret

        ENDP


;**********************************************************************
;* Proc. Name     : Allocate4KPage
;* Function       : 
;**********************************************************************
; FUNCTION Allocate4KPage: HugePtr;

Allocate4KPage PROC FAR
               PUBLIC  Allocate4KPage

        vcpi    04h
        or      ah,ah
        jnz     @@1
        mov     ax,dx   ; Success, phys. addr. in EDX returned in DX:AX
        shr     edx,16
        ret
@@1:    xor     ax,ax   ; Failed, return 0
        xor     dx,dx
        ret

Allocate4KPage  ENDP

;**********************************************************************
;* Proc. Name     : Free4KPage
;* Function       : 
;**********************************************************************
; FUNCTION Free4KPage(PhysAddr: HugePtr): BOOLEAN;

Free4KPage PROC FAR PhysAddr: DWORD;
           PUBLIC Free4KPage

        mov     edx,PhysAddr
        vcpi    5
        or      ah,ah
        jnz     @@1
        mov     al,1
        ret
@@1:    xor     al,al
        ret

Free4KPage  ENDP

;**********************************************************************
;* Proc. Name     : Avail4KPages
;* Function       : Returns no. of free 4K pages
;**********************************************************************
; FUNCTION Avail4KPages: LONGINT;

Avail4KPages PROC FAR 
             PUBLIC Avail4KPages

        vcpi    3
        mov     ax,dx
        shr     edx,16
        ret

Avail4KPages  ENDP

;**********************************************************************
;* Proc. Name     : GetPhysAddr
;* Function       : Translates a page address in 1st MB to a
;*                  physical address
;**********************************************************************

; FUNCTION GetPhysAddr(PageNo: WORD): HugePtr;

GetPhysAddr  PROC FAR PageNo: WORD;
             PUBLIC GetPhysAddr

        mov     cx,PageNo
        vcpi    06h
        or      ah,ah
        jnz     @@1
        mov     ax,dx
        shr     edx,16
        ret
@@1:    mov     ax,0FFFFH       ; failed, return 0FFFFFFFFH
        mov     dx,ax
        ret

GetPhysAddr  ENDP






;**********************************************************************
;* Proc. Name     : CallProtectedMode
;* Function       : Jumps to protected mode. All params must be in
;*                  PMParam global rec.
;**********************************************************************
;PROCEDURE CallProtectedMode(PMPar: HugePtr) ; 

CallProtectedMode  PROC FAR ParamAddr: DWORD;
                   PUBLIC CallProtectedMode;



        cli

                                ; Push v86 rec. to stack
        mov     si,offset v86.ret32
        mov     cx,22           ; bytes in v86 
        cld
@@2:    lodsw
        push    ax
        loop    @@2

        push    ebp
        mov     v86.ip86,OFFSET @@1
        mov     v86.cs86,cs
        mov     v86.ss86,ss
        mov     v86.ds86,ds
        mov     v86.sp86,sp
        mov     esi,ParamAddr
        vcpi    0CH             ; Switch to protected mode

@@1:    
        pop     ebp
                                ; pop v86 rec.

        mov     di,offset v86.ret32 + 42
        mov     cx,22
        mov     ax,ds
        mov     es,ax
        std
@@3:    pop     ax
        stosw
        loop    @@3
        cld

        sti                     ; returns here
        ret


CallProtectedMode  ENDP

        END
