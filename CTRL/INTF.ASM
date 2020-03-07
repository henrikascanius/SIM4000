;**********************************************************************
;*****
;*****              RC8000 SIMULATOR FOR 80386/80486
;*****
;*****      Designed and programmed by Henrik Jacobsen  1992.
;*****
;*****
;*****  INTF.ASM : Interface routines Pascal <-> Simulator
;*****             These routines run in protected mode.
;*****
;**********************************************************************
;***** Channge history:
;***** 94-11-13 22:34 HJ Cleanup code from prev. versions in _Run8000
;*****
;**********************************************************************

        MASM 
        .386P

        LOCALS @@

        INCLUDE select.asm
        INCLUDE structs.asm
        INCLUDE MACROS.ASM


run_p   EQU     4000H
BadOp_p EQU     4004H
Break_p EQU     4008H


Base8259_1 EQU  20H     ; IO base of primary interrupt controller
IntBase_1  EQU  8       ; Interrupt base of primary interrupt controller

DummySrvc  EQU  3       ; Service code for dummy service (switch screen)


;**********************************************************************
;*****
;*****         Macro for return from prot. mode to V86 mode
;*****
;**********************************************************************

retv86  MACRO
        cli
        mov     ax,PascData                  ; set stack for return to V86
        mov     es,ax
        mov     ss,ax
        xor     eax,eax
        mov     ax,OFFSET v86.ip86
        mov     esp,eax

        mov     ax,VCPIDS
        mov     ds,ax
        mov     eax,0de0ch
        call    es:fword ptr [VcpiPMentry]
        ENDM

;**********************************************************************
;*****
;*****              Macro for setting up an empty stack
;*****
;**********************************************************************


EmptyPMStack MACRO

        mov     ax,PMStack
        mov     ss,ax
        xor     esp,esp
        lsl     sp,ax          ; Load segment limit
        sub     sp,1           ; Point to last word (stack is 16-bit)

        ENDM


EmptyPMIStack MACRO

        mov     ax,PMIStack
        mov     ss,ax
        xor     esp,esp
        lsl     sp,ax          ; Load segment limit
        sub     sp,1           ; Point to last word (stack is 16-bit)

        ENDM
;**********************************************************************
;*****
;*****                Macro for initalising es,fs,gs
;*****
;**********************************************************************

InitSRegs MACRO
        xor     ax,ax
        mov     fs,ax
        mov     gs,ax
        mov     es,ax
        ENDM

;**********************************************************************
;*****
;*****          Macro for conditional enable of interrupts
;*****
;**********************************************************************
ChkSti  MACRO
        LOCAL @@1
        test    State8000.Running,1
        jnz     @@1
        sti
@@1:    
        ENDM

;**********************************************************************
;*****
;*****              Macro for evaluation of RC-interrupts
;*****
;**********************************************************************

        ; ONLY USE EAX!!!

Eval8000Int     MACRO
        LOCAL @@1,@@2

        mov     eax,es:DWORD PTR [_IR]
        bt      eax,31                  ; test instr. exception
        jc      @@2                     ; (cannot be disabled)

        test    es:BYTE PTR [_IntEn],1
        jz      @@1                     ; Return ZF if int. disabled

@@2:
        and     eax,es:DWORD PTR [_IM]
@@1:  
        ENDM


NoBreakAtFetch MACRO
        mov     ax,SCode
        mov     gs,ax
        ENDM

BreakAtFetch MACRO
        mov     ax,BreakSeg
        mov     gs,ax
        ENDM

TestExtInts MACRO
        LOCAL NoInt,Int

        push    es
        mov     ax,State8Seg
        mov     es,ax
        test    es:BYTE PTR [_Stop],1
        jnz     Int
        test    es:BYTE PTR [_IntEn],1
        jz      NoInt                   ; Return ZF if int. disabled
        mov     eax,es:DWORD PTR [_IR]
        and     eax,es:DWORD PTR [_IM]
        shl     eax,3                   ; dispose of internal exceptions
        jnz     Int                   
        cmp     es:BYTE PTR [_NextScreen],0FFH ; Test for screen switch request
        jne     NoInt

Int:
        BreakAtFetch                    ; We may catch an interrupt already
                                        ; in progress, but never mind...
                                        ; It is OK to make un-necessary
                                        ; breaks.
NoInt:
        pop     es
        ENDM

;**********************************************************************
;*****
;*****                     END OF MACRO SECTION
;*****
;**********************************************************************


DATA    SEGMENT USE16 PUBLIC

        EXTRN   v86: v86def
        EXTRN   VcpiPMEntry: FWORD
        EXTRN   PMParam: PMEntDef
        EXTRN   CoreCopyPar: CopyRec
        EXTRN   CoreSize: DWORD
        EXTRN   State8000: State8000Rec
        EXTRN   CoreBase: DWORD;
        EXTRN   CodeBase: DWORD;
        EXTRN   SrvcIntNo: BYTE;


sssave  DW      ?       ; save SS  during interrupt simulation
espsave DD      ?       ; save ESP during interrupt simulation
dr0save DD      ?       ; save DR0 during interrupt simulation
dr1save DD      ?       ; save DR1 during interrupt simulation
dr2save DD      ?       ; save DR2 during interrupt simulation
dr7save DD      ?       ; save DR7 during interrupt simulation

Run     DP      ?       ; Copy of Run entry point
BadOp   DP      ?       ; Copy of Bad Opcode entry point
Break   DP      ?       ; Copy of Break entry point

DATA    ENDS


;**********************************************************************
;*****
;*****           Define pointers to State8000 zero-relative
;*****
;**********************************************************************

_IC       EQU   OFFSET State8000.IC             - OFFSET State8000
_IM       EQU   OFFSET State8000.IM             - OFFSET State8000
_IR       EQU   OFFSET State8000.IR             - OFFSET State8000
_IntEn    EQU   OFFSET State8000.IntEn          - OFFSET State8000
_Step     EQU   OFFSET State8000.Step           - OFFSET State8000
_Trace    EQU   OFFSET State8000.Trace          - OFFSET State8000
_Stop     EQU   OFFSET State8000.Stop           - OFFSET State8000
_NextScreen EQU OFFSET State8000.NextScreen     - OFFSET State8000

; SrvcParam part:
_ReqKind  EQU   OFFSET State8000.ReqKind        - OFFSET State8000
_WReg     EQU   OFFSET State8000.WReg           - OFFSET State8000
_EA       EQU   OFFSET State8000.EA             - OFFSET State8000
_Optional EQU   OFFSET State8000.Optional       - OFFSET State8000



;**********************************************************************
;*****
;*****                     Start of code segment
;*****
;**********************************************************************


CODE    SEGMENT USE16 PUBLIC
        ASSUME CS:Code,DS:Data


_SetBreakSeg PROC FAR
        PUBLIC _SetBreakSeg

        mov     ax,PascData
        mov     ds,ax
        InitSRegs
        EmptyPMIStack

        mov     ax,SCode                ; Init. pointers to aux. routines
        mov     es,ax
        mov     ebx,es:DWORD PTR [run_p]
        mov     DWORD PTR [Run],ebx
        mov     WORD PTR [Run+4],ax
        mov     ebx,es:DWORD PTR [BadOp_p]
        mov     DWORD PTR [BadOp],ebx
        mov     WORD PTR [BadOp+4],ax
        mov     ebx,es:DWORD PTR [break_p]
        mov     DWORD PTR [Break],ebx
        mov     WORD PTR [Break+4],ax
        mov     ax,BreakSeg
        mov     es,ax
        ChkSti

        mov     eax,DWORD PTR [Break]
        mov     ecx,4096
        xor     edi,edi
        cld
        db      67H
        rep stosd

        retv86

_SetBreakSeg ENDP


;**********************************************************************
;*****
;*****                          NOTE ON IC:
;*****
;*****  In the State8000 record, the IC field is a RC8000 word address,
;*****  i.e. the "real" IC register shifted one pos. right.
;*****  When running, the ESI register holds the "real" IC value
;*****  SHIFTED ONE POS. TO THE LEFT, i.e. it is incremeted by 4
;*****  in each instruction cycle. 
;*****
;**********************************************************************

;**********************************************************************
;* Proc. Name     : _Run8000
;* Function       : Start RC8000 execution.
;**********************************************************************
_Run8000  PROC FAR
        PUBLIC _Run8000

        mov     ax,PascData
        mov     ds,ax

        InitSRegs
        EmptyPMStack

        ; Initialise nummeric processor:
        fninit
        mov     ax,0E3FH        ; Round to zero, double prec., mask all exc.
        push    ax
        fldcw   ss:WORD PTR [esp]
        fwait
        pop     ax



        ; set debug registers
        ; USE: DR0: Not used (anymore)
        ;      DR1: Step breakpoint (at IC+2)
        ;      DR2: User-defined breakpoint

        xor     ebx,ebx         ; Build DR7 in ebx
        mov     dr7,ebx         ; disable all (to avoid ooops'es)

        test    State8000.Step,1
        jz      @@1
                                ; Step: set brp. at IC+2
        mov     eax,State8000.IC
        inc     eax
        shl     eax,2
        add     eax,CoreBase
        mov     dr1,eax
        or      ebx,00300008H   ; Brp1 Global, R/W
@@1:
        test    State8000.Trace,1
        jnz     @@2

        mov     eax,State8000.Brp
        inc     eax
        jz      @@2             ; -1 means no breakpoint
                                ; User-defined brp: Word address, MSB=1 if W.O.
        dec     eax

        or      eax,eax
        jl      @@3             ; jump if Write-Only
        or      ebx,02000000H   ; Set the left RW2 bit
@@3:    or      ebx,01000020H   ; Brp2 Global

        shl     eax,2           ; and off w. MSB...
        add     eax,CoreBase
        mov     dr2,eax
@@2:
        ; ***** dr7 set AFTER fetch of 1st instr. ****
        ; DON'T FIDDLE AROUND WITH EBX AFTER HERE!

        
        xor     eax,eax
        mov     dr6,eax         ; clear status reg.
                                ; Debug regs now set.





        xor     edi,edi         ; req. by simulator
        mov     ch,State8000.Ex22
        mov     cl,State8000.Ex23

        mov     esi,State8000.IC
        shl     esi,2
        mov     State8000.Running,1

        push    ds
        pop     fs              ; used later

        mov     ax,CoreSeg
        mov     ds,ax   

        mov     ax,State8Seg
        mov     es,ax           ; Get addressability of machine state record

        mov     ax,SCode
        mov     gs,ax           ; entry table segment

        sti
        jmp     fs:Run          ; fs holds PascData decr.

_Run8000  ENDP


;**********************************************************************
;* Proc. Name     : _FromCore
;* Function       : Copy from Core to V86 
;**********************************************************************
_FromCore  PROC FAR
        PUBLIC _FromCore

        mov     ax,PascData
        mov     ds,ax

        InitSRegs
        EmptyPMIStack
        ChkSti

        xor     ecx,ecx
        mov     cx,CoreCopyPar.Words    ; No. of DWORDS to move
        mov     esi,CoreCopyPar.Addr    ; The address in Core 
        shl     esi,1
        mov     edi,CoreCopyPar.V86Ref

        mov     ax,CoreCopyPar.V86Seg
        mov     es,ax                   ; dest. segm.
        mov     ax,CoreCopyPar.PMSeg
        mov     ds,ax                   ; Source segm.

        cld
        db 67H                          ; ADDRSIZE 
        rep movsd                       ; move it...

        retv86

_FromCore ENDP


;**********************************************************************
;* Proc. Name     : _ToCore
;* Function       : Copy from Core to V86 
;**********************************************************************
_ToCore  PROC FAR
        PUBLIC _ToCore

        mov     ax,PascData
        mov     ds,ax

        InitSRegs
        EmptyPMIStack
        ChkSti

        xor     ecx,ecx
        mov     cx,CoreCopyPar.Words    ; No. of DWORDS to move
        mov     edi,CoreCopyPar.Addr    ; The address in Core 
        shl     edi,1

        mov     esi,CoreCopyPar.V86Ref
        mov     ax,CoreCopyPar.PMSeg
        mov     es,ax                   ; Dest. segm.
        mov     ax,CoreCopyPar.V86Seg
        mov     ds,ax                   ; Source segm.


        cld
        db 67H                          ; ADDRSIZE 
        rep movsd                       ; move it...

        retv86

_ToCore ENDP

;**********************************************************************
;*****
;*****                      PACKING COPY ROUTINES
;*****
;***** Format in Core:       Format on e.g. disc:
;*****                  cba0            dcba                           
;*****                  fed0            hgfe
;*****                  ihg0            lkji
;*****                  lkj0
;*****
;**********************************************************************

lodsdd  MACRO
        db 67H                          ; ADDRSIZE 
        lodsd
        ENDM

stosdd  MACRO
        db 67H                          ; ADDRSIZE 
        stosd
        ENDM

;**********************************************************************
;* Proc. Name     : _FromCoreP
;* Function       : Copy from Core to V86, w. 24->32bpw packing
;**********************************************************************
_FromCoreP  PROC FAR
        PUBLIC _FromCoreP

        mov     ax,PascData
        mov     ds,ax

        InitSRegs
        EmptyPMIStack
        ChkSti

        xor     ecx,ecx
        mov     cx,CoreCopyPar.Words    ; No. of DWORDS to move
        shr     ecx,2                   ; moves 4 dwords at a time   
        mov     esi,CoreCopyPar.Addr    ; The address in Core 
        shl     esi,1
        mov     edi,CoreCopyPar.V86Ref

        mov     ax,CoreCopyPar.V86Seg
        mov     es,ax                   ; dest. segm.
        mov     ax,CoreCopyPar.PMSeg
        mov     ds,ax                   ; Source segm.

        cld
@@1:
        lodsdd
        mov     ebx,eax                 ; Packing - no comments...
        lodsdd
        mov     edx,eax
        lodsdd
        shr     eax,8
        shrd    edx,eax,8
        shrd    ebx,edx,8
        shr     eax,8
        shrd    edx,eax,8
        shr     eax,8
        xchg    ebx,eax
        stosdd
        mov     eax,edx
        stosdd
        lodsdd
        or      eax,ebx
        stosdd
        loop    @@1

        retv86

_FromCoreP ENDP


;**********************************************************************
;* Proc. Name     : _ToCoreP
;* Function       : Copy from Core to V86 
;**********************************************************************
_ToCoreP  PROC FAR
        PUBLIC _ToCoreP

        mov     ax,PascData
        mov     ds,ax

        InitSRegs
        EmptyPMIStack
        ChkSti

        xor     ecx,ecx
        mov     cx,CoreCopyPar.Words    ; No. of DWORDS to move
        shr     ecx,2                   ; moves 4 dwords at a time   
        mov     edi,CoreCopyPar.Addr    ; The address in Core 
        shl     edi,1

        mov     esi,CoreCopyPar.V86Ref
        mov     ax,CoreCopyPar.PMSeg
        mov     es,ax                   ; Dest. segm.
        mov     ax,CoreCopyPar.V86Seg
        mov     ds,ax                   ; Source segm.


        cld
@@1:
        lodsdd
        mov     ebx,eax
        shl     eax,8
        stosdd
        lodsdd
        mov     edx,eax
        lodsdd
        shrd    ebx,edx,16
        xor     bl,bl
        shrd    edx,eax,8
        xor     dl,dl
        xor     al,al
        xchg    eax,ebx
        stosdd
        mov     eax,edx
        stosdd
        mov     eax,ebx
        stosdd
        loop    @@1

        retv86

_ToCoreP ENDP

;**********************************************************************
;*****
;*****                PACKING SWAPPING COPY ROUTINES
;*****
;***** As the Packing routines, but swaps bytes in each word to make a
;***** correct textstring transfer betw. RC8000 and DOS. Slower than
;***** the non-swapping routines!
;*****
;*****
;**********************************************************************

;**********************************************************************
;* Proc. Name     : _FromCoreTxt
;* Function       : Copy from Core to V86 w. swapping
;**********************************************************************
_FromCoreTxt  PROC FAR
        PUBLIC _FromCoreTxt

        mov     ax,PascData
        mov     ds,ax

        InitSRegs
        EmptyPMIStack
        ChkSti

        xor     ecx,ecx
        mov     cx,CoreCopyPar.Words    ; No. of DWORDS to move
        mov     esi,CoreCopyPar.Addr    ; The address in Core 
        shl     esi,1
        mov     edi,CoreCopyPar.V86Ref

        mov     ax,CoreCopyPar.V86Seg
        mov     es,ax                   ; dest. segm.
        mov     ax,CoreCopyPar.PMSeg
        mov     ds,ax                   ; Source segm.

        cld
@@1:
        db 67H                          ; ADDRSIZE 
        lodsd
        rol     eax,8
        db 67H                          ; ADDRSIZE 
        stosb
        rol     eax,8
        db 67H                          ; ADDRSIZE 
        stosb
        rol     eax,8
        db 67H                          ; ADDRSIZE 
        stosb
        loop    @@1

        retv86

_FromCoreTxt ENDP


;**********************************************************************
;* Proc. Name     : _ToCoreTxt
;* Function       : Copy from Core to V86 w. swapping
;**********************************************************************
_ToCoreTxt  PROC FAR
        PUBLIC _ToCoreTxt

        mov     ax,PascData
        mov     ds,ax

        InitSRegs
        EmptyPMIStack
        ChkSti

        xor     ecx,ecx
        mov     cx,CoreCopyPar.Words    ; No. of DWORDS to move
        mov     edi,CoreCopyPar.Addr    ; The address in Core 
        shl     edi,1

        mov     esi,CoreCopyPar.V86Ref
        mov     ax,CoreCopyPar.PMSeg
        mov     es,ax                   ; Source segm.
        mov     ax,CoreCopyPar.V86Seg
        mov     ds,ax                   ; Source segm.


        cld
@@1:
        db 67H                          ; ADDRSIZE 
        lodsb
        shl     eax,8
        db 67H                          ; ADDRSIZE 
        lodsb
        shl     eax,8
        db 67H                          ; ADDRSIZE 
        lodsb
        shl     eax,8
        db 67H                          ; ADDRSIZE 
        stosd
        loop    @@1

        retv86

_ToCoreTxt ENDP

;**********************************************************************
;* Proc. Name     : _FromCode
;* Function       : Copy from simul. code segm. to V86 
;**********************************************************************
_FromCode  PROC FAR
        PUBLIC _FromCode

        mov     ax,PascData
        mov     ds,ax

        InitSRegs
        EmptyPMIStack
        ChkSti

        xor     ecx,ecx
        mov     cx,CoreCopyPar.Words    ; No. of BYTES to move
        mov     esi,CoreCopyPar.Addr    ; The address...
        mov     edi,CoreCopyPar.V86Ref

        mov     ax,CoreCopyPar.V86Seg
        mov     es,ax                   ; dest. segm.
        mov     ax,CoreCopyPar.PMSeg
        mov     ds,ax                   ; Source segm.

        cld
        db 67H                          ; ADDRSIZE 
        rep movsb                       ; move it...

        retv86

_FromCode ENDP


;**********************************************************************
;* Proc. Name     : _ToCode
;* Function       : Copy from simul. Code to V86 
;**********************************************************************
_ToCode  PROC FAR
        PUBLIC _ToCode

        mov     ax,PascData
        mov     ds,ax

        InitSRegs
        EmptyPMIStack
        ChkSti

        xor     ecx,ecx
        mov     cx,CoreCopyPar.Words    ; No. of BYTES to move
        mov     edi,CoreCopyPar.Addr    ; The address 

        mov     esi,CoreCopyPar.V86Ref
        mov     ax,CoreCopyPar.PMSeg
        mov     es,ax                   ; Dest. segm.
        mov     ax,CoreCopyPar.V86Seg
        mov     ds,ax                   ; Source segm.


        cld
        db 67H                          ; ADDRSIZE 
        rep movsb                       ; move it...

        retv86

_ToCode ENDP

;**********************************************************************
;* Proc. Name     : ResetCore
;* Function       : Sets each word in core eq. to its own address
;**********************************************************************
_ResetCore  PROC FAR
        PUBLIC _ResetCore

        mov     ax,PascData
        mov     ds,ax

        InitSRegs
        EmptyPMIStack
        ChkSti

        mov     ecx,CoreSize
        shr     ecx,1
        xor     edi,edi
        xor     eax,eax
        mov     bx,CoreSeg
        mov     es,bx


@@1:
        mov     es:DWORD PTR [edi],eax
        add     edi,4
        add     eax,256
        loopd   @@1

        retv86

_ResetCore  ENDP


;**********************************************************************
;* Proc. Name     : _IntSim
;* Function       :Simulates (reflects) an interrupt to V86 mode.
;**********************************************************************

_IntSim PROC NEAR

        ; Interrupts must be disabled when calling.
        ; BL holds interrupt number.
        ; Assumes PascData selector in DS

        mov     espsave,esp             ; save SP
        mov     ax,ss
        mov     sssave,ax
        mov     eax,dr7         
        mov     dr7save,eax             ; Save DR7
        mov     eax,dr0         
        mov     dr0save,eax             ; Save DR0
        mov     eax,dr1         
        mov     dr1save,eax             ; Save DR1
        mov     eax,dr2         
        mov     dr2save,eax             ; Save DR2

        xor     eax,eax
        mov     dr7,eax

        mov     ax,PascStack
        mov     ss,ax                   ; selector for V86 stack segm.
        mov     sp,v86.sp86             ; Now we can work on the V86 stack

                                        ; Save V86 ds,cs,ip,sp on stack
        push    v86.sp86
        push    v86.cs86
        push    v86.ds86
        push    v86.ip86
                                        ; push flags, far ret. addr. for IRET
        push    6000H                   ; IOPL=3, IE=0
        push    SEG _IntSim             ; .EXE loader will make fixup!
        push    offset @@1

        mov     v86.sp86,sp             ; set stack pointer

                                        ; fetch handler addr.
        mov     ax,VCPIDS               ; has base addr = 0
        mov     es,ax
        xor     bh,bh
        shl     bx,2
        mov     ax,es:WORD PTR [bx]
        mov     v86.ip86,ax
        mov     ax,es:WORD PTR [bx+2]
        mov     v86.cs86,ax

        mov     ax,ds                   ; set stack
        mov     ss,ax
        xor     eax,eax
        mov     ax,OFFSET v86.ip86
        mov     esp,eax

        mov     ax,ds                   ; swop es,ds
        mov     bx,es
        mov     ds,bx
        mov     es,ax
        
        mov     eax,0de0ch
        call    es:fword ptr [VcpiPMentry] ; go V86...

@@1:                                    ; NOW V86 mode: int. handler ret. here
        cli                             ; necessary?

        xor     eax,eax
        mov     ax,offset @@2
        mov     PMParam.PMEIP,eax       ; rest of PMParam is OK

        xor     esi,esi                 ; calc. lin. addr of PMParam
        mov     si,SEG PMParam
        shl     esi,4
        xor     edi,edi
        mov     di,offset PMParam
        add     esi,edi
        mov     ax,0de0ch
        int     67H                     ; switch to protected mode


@@2:                                    ; Back in PM again!
        
        mov     ax,PascData             ; find our feet
        mov     ds,ax

        mov     ax,PascStack
        mov     ss,ax                   ; selector for V86 stack segm.
        mov     sp,v86.sp86             ; Now we can work on the V86 stack
        add     sp,6                    ; pop flags,far ptr for return

        pop     v86.ip86                ; restore v86 block
        pop     v86.ds86
        pop     v86.cs86
        pop     v86.sp86

        mov     ax,sssave               ; restore PM stack access
        mov     ss,ax
        mov     esp,espsave

        mov     eax,dr7save
        mov     dr7,eax
        mov     eax,dr0save
        mov     dr0,eax
        mov     eax,dr1save
        mov     dr1,eax
        mov     eax,dr2save
        mov     dr2,eax

        ret                             ; leaving interrupts off..


_IntSim ENDP

;**********************************************************************
;*****
;*****                   INTERRUPT HANDLER SECTION
;*****
;**********************************************************************


;**********************************************************************
;*****
;*****                  Prelude and postlude macros
;*****
;**********************************************************************


IntStart MACRO 
        push    ds
        pushad
        mov     ax,PascData
        mov     ds,ax
        mov     bp,sp

        mov     bx,WORD PTR [bp+34]     ; ret. address placed by near CALL
        sub     bx,offset IntHandler    ; distance from start of table
        shr     bx,2                    ; gives interrupt no.
        ENDM


IntRet  MACRO
        add     sp,2                    ; The near address from CALL 
        iretd
        ENDM

IntEnd  MACRO
        popad
        pop     ds
        IntRet
        ENDM

PushSegs MACRO
        push    es
        push    fs
        push    gs
        ENDM

PopSegs MACRO
        pop     gs
        pop     fs
        pop     es
        ENDM

Halt8000 MACRO  ; assumes DS=PascData, BP as set by IntStart
        LOCAL @@1

        test    State8000.Running,1
        jz      @@1                     ; not running
        mov     State8000.Running,0

        xor     eax,eax
        mov     dr6,eax                 ; Clear all Brp.
        mov     dr7,eax                 ; Disable all Brp.

                                        ; Save RC8000 state
        mov     eax,DWORD PTR [bp+4]    ; Stacked ESI
        shr     eax,2
        mov     State8000.IC,eax
        mov     ax,WORD PTR [bp+24]     ; Stacked CX
        mov     State8000.Ex22,ah
        mov     State8000.Ex23,al
@@1:
        ENDM






IntHandler  PROC FAR
        PUBLIC IntHandler

        ; NOTE: The "iret"'s are not executed. They just make each entry take 
        ;       4 bytes!

        call    ih_div0         ; int 0, Divide fault
        iret

        call    ih_debug        ; int 1, Debug
        iret

        REPT    2
        call    ih_common       ; int. 2-3
        iret
        ENDM

        call    ih_ovf          ; int. 4, overflow
        iret


        REPT    3               ; int. 5-7
        call    ih_common
        iret
        ENDM


        REPT    8               ; int. 8-F
        call    ih_hw1
        iret
        ENDM

        REPT    60H             ; int. 10-6F
        call    ih_common
        iret
        ENDM

        REPT    8               ; int. 70-77
        call    ih_hw2
        iret
        ENDM

        REPT    88H             ; int. 78-FF
        call    ih_common
        iret
        ENDM

;**********************************************************************
;*****
;*****                 Hardware interrupts, 1st 8259
;*****
;**********************************************************************

InSrvc  MACRO   Int             ; Test if interrupt "Int" is in service
        mov     al,1011B
        out     Base8259_1,al   ; OCW3: Read ISR
        in      al,Base8259_1
        mov     cl,&Int
        sub     cl,IntBase_1-1
        shr     al,cl           ; selected bit to CF
        ENDM


ih_hw1: 
        IntStart
        PushSegs
        InSrvc  bl
        jnc     hw1_not

;        cmp     bl,8
;        je      x2                      ; jump on timer

        call    NEAR PTR _IntSim        ; Int. no passes in BL
        mov     ax,VCPIDS
        mov     es,ax
x1:    
        PopSegs
        TestExtInts
        IntEnd

x2:     
        call    NEAR PTR _IntSim        ; Int. no passes in BL
        test    State8000.Running,1
        jz      x1
        PopSegs
        TestExtInts
        IntEnd

hw1_not: 
        cmp     bl,0DH                  ; GP Fault?
        jne     ih_common

        mov     ebx,DWORD PTR [BadOp]   ; GP fault assumed to be address viol.
        PopSegs                         
        mov     eax,esp
        mov     DWORD PTR ss:[eax+40],ebx; Modify offset part of return adresss
        popad
        pop     ds
        add     sp,6                    ; CALL-addr + 32-bit error code
        iretd

;**********************************************************************
;*****
;*****                 Hardware interrupts, 2nd 8259
;*****
;**********************************************************************


ih_hw2:  
        IntStart
        PushSegs
        call    NEAR PTR _IntSim        ; Int. no passes in BL
        PopSegs
        TestExtInts
        IntEnd



;**********************************************************************
;*****
;*****                       Integer overflow
;*****
;**********************************************************************

ih_div0:
        mov     ch,1                    ; set overflow (see WD operation)
        xor     eax,eax
        xor     edx,edx
        mov     ebx,1                   ; Avoid new fault on return (DIRTY!)
ih_ovf:
        bts     es:DWORD PTR [_IR],30   ; Set integer overflow in IR
        bt      es:DWORD PTR [_IM],30   ; Masked?
        jc      ih_ovf1
        IntRet

ih_ovf1:
        BreakAtFetch
        IntRet

;**********************************************************************
;*****
;*****                          Debug fault/trap
;*****
;**********************************************************************

; We strongly assume that this fault only occurs when RC8000 is "running",
; i.e. DS addresses Core, ES Addresses State8000.


ih_debug:   

        ; Make "dummy" service interr. to make virt. screen switching
        cmp     es:BYTE PTR [_NextScreen],0FFH
        je      NoScSw
        mov     es:BYTE PTR [_ReqKind],DummySrvc
        pushad
        push    ds
        PushSegs
        mov     ax,PascData
        mov     ds,ax
        mov     bl,SrvcIntNo
        call    NEAR PTR _IntSim
        PopSegs
        pop     ds
        popad

NoScSw:
        test    es:BYTE PTR [_Trace],1
        jnz     Trc1                    ; jump if tracing

        test    es:BYTE PTR [_Stop],1
        jnz     Trc1

        mov     eax,dr7                 ; test for Step
        mov     ebx,dr6
        test    al,8
        jz      UBrp                    ; jump if not active
        test    bl,2
        jnz     Trc1

UBrp:
        test    al,20H                  ; test for user breakpoint
        jz      Dum                     ; jump if not active
        test    bl,4
        jz      Dum
Trc1:
        ; User breakpoint triggered
        IntStart
        Halt8000
        retv86                          ; return to user screen

Dum:                                    ; It was just a dummy DR0-trig
        xor     eax,eax
        mov     dr6,eax                 ; Clear status

        NoBreakAtFetch
        IntRet                          ; DR0 is a FAULT, therefore we
                                        ; can just restart



;**********************************************************************
;*****
;*****                      END OF DEBUG FAULT/TRAP
;*****
;**********************************************************************


ih_common: 
        IntStart
        cmp     bl,SrvcIntNo            ; Service req. interrupt?
        jne     ShowInt

        PushSegs
        call    NEAR PTR _IntSim        ; Int. no passes in BL

        PopSegs
        TestExtInts

        IntEnd

        
IntHandler ENDP

;**********************************************************************
;*****
;*****                   VERY DIRTY DEBUG SUPPORT
;*****
;**********************************************************************

        INCLUDE prt.asm ; The nasty-nasty printer routines

ShowInt:
        mov     ax,bx
        xor     ah,ah
        call    prt16
        popad
        pop     ds
        add     sp,2
        mov     ebp,esp

        mov     al,[ebp]
        call    prtalx

        mov     eax,[ebp+1]
        call    prtalx

        mov     eax,[ebp+2]
        call    prtalx

        mov     eax,[ebp+3]
        call    prtalx

        mov     eax,[ebp+4]
        call    prtalx

        mov     eax,[ebp+5]
        call    prtalx

        mov     eax,[ebp+6]
        call    prtalx

        mov     eax,[ebp+7]
        call    prtalx

        mov     eax,[ebp+8]
        call    prtalx

        call newln

        mov     eax,dr0
        call    prteaxx

        mov     eax,dr6
        call    prteaxx

        mov     eax,dr7
        call    prteaxx

        call newln

_x:     jmp _x
        

CODE    ENDS
        
        END



