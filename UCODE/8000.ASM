;**********************************************************************
;*****
;*****              RC8000 SIMULATOR FOR 80386/80486
;*****
;*****      Designed and programmed by Henrik Jacobsen  1992.
;*****
;*****
;*****  8000.ASM : Common frame for the RC8000 code interpreter modules.
;*****
;**********************************************************************

        MASM 
        .386P
        .387

        INCLUDE MAKEMAC.ASM
        INCLUDE OPUTIL.ASM
        INCLUDE ..\CTRL\S8.ASM
        INCLUDE ..\CTRL\SELECT.ASM

Data    SEGMENT USE32
Data    ENDS

Stck    SEGMENT USE16
Stck    ENDS

;**********************************************************************
;*****
;*****  Define segment for access to State8000 from protected mode
;*****
;**********************************************************************


STATE   SEGMENT USE16

        ORG     0
S8      LABEL State8000Rec   

STATE   ENDS


Code    SEGMENT USE32
        ASSUME CS:Code,DS: Data, ES: STATE, SS: Stck



;**********************************************************************
;*
;*               MAP OF CODE SEGMENT WHEN LOADED:
;*
;*      0h : optable
;*   4000h : fetch
;*   4040h : run
;*   4080h : afteramfetch
;*   4100h : Bad opcode handling
;*   4180h : Break
;*
;* Each module (part) has its own opcode table for the instructions
;* defined in that module. The fetch code is placed in part0, right
;* after the module's opcode table.
;*
;*
;**********************************************************************





        ORG 100h                ; Required to make a .COM file

Start:
        dw      4096 dup (0)    ; Init. entry point table

Addr    =       $

; assume DI[31..16] is 0!!!

fetch           EQU     4000H
run             EQU     4040H
afteramfetch    EQU     4080H
BadOpCode       EQU     4100H
Break8000       EQU     4180H
optable         EQU     0



        IFDEF Part0


;fetch:                                 ; fetch instruction
        mov     eax,[esi]
fetch1  EQU     SMALL $-100H+2000H      ; Opcode table is 16-bit when assembling,
                                        ; 32-bit when running
        rol     eax,12

        mov     di,ax
        sar     eax,12                  ; place D-field as operand in EAX
        jmp     gs:DWORD PTR optable[edi*4]

        ORG     100H+run-2000H
;run:                                   ; Entry point for _Run8000

        mov     eax,[esi]
        test    ebx,2
        jz      NoBp0
        and     ebx,-1-2
        BreakAtFetch
NoBp0:
        mov     dr7,ebx                 ; set breakpoint AFTER 1st fetch
        xor     edi,edi                 ; edi[31..16] must always be 0

        rol     eax,12

        mov     di,ax
        sar     eax,12                  ; place D-field as operand in EAX
        jmp     cs:DWORD PTR optable[edi*4]


        ORG     100H+afteramfetch-2000H

;afteramfetch:                          ; fetch instruction
        mov     ebx,eax
        mov     eax,[esi]
        rol     eax,12
        mov     di,ax
        sar     eax,12                  ; place D-field as operand in EBX
        add     eax,ebx                 ; add to EA of prev. am instr.
        jmp     cs:DWORD PTR optable[edi*4]


        ORG     100H+BadOpCode-2000H

;BadOpCode:                             ; All GP faults also ends here...
                                        ; (assumed to be address violations)
        or      S8.IR,80000000H         ; Set instr. exception
        breakatfetch
        incic


        ORG     100H+Break8000-2000H
;Break8000:
        mov     eax,S8.IR
        bt      eax,31                  ; test instr. exception
        jc      _Int                    ; (cannot be disabled)

        test    es:S8.IntEn,1
        jz      _NoInt

_Int:
        and     eax,S8.IM
        jz      _NoInt

        ; *********** MAKE RC4000 INTERRUPT: ************
        cli
                                        ; avoid trig of breakpoints while 
        mov     ebx,dr7                 ; modifying core
        push    ebx
        xor     ebx,ebx
        mov     dr7,ebx                 
        bsr     eax,eax                 ; get bit no.
        btr     S8.IR,eax               ; clear bit in IR
        btr     WORD PTR S8.IntEn,0     ; Int. disable
        sub     al,31
        neg     al
        shl     eax,9                   ; 2*intno ready to save
        mov     DS:DWORD PTR [16],eax   ; intno. to core[8]

        shl     esi,7
        mov     DS:DWORD PTR [20],esi   ; return addr. to core[10]

        mov     esi,DS:DWORD PTR [24]   ; service address in core[12]
        sar     esi,9
        shl     esi,2

        pop     ebx
        mov     dr7,ebx
        sti
_NoInt:  
        cmp     S8.NextScreen,0FFH
        jne     _Br
        mov     al,S8.Trace
        or      al,S8.Stop
        jnz     _Br
        mov     ax,cs
        mov     gs,ax
        FetchNext
        
_Br:
        int     1
        FetchNext

        ENDIF




        IFDEF Part0
        INCLUDE INSTMAC0.ASM
        ENDIF

        IFDEF Part1
        INCLUDE INSTMAC1.ASM
        ENDIF

        IFDEF Part2
        INCLUDE INSTMAC2.ASM
        ENDIF

        IFDEF Part3
        INCLUDE INSTMAC3.ASM
        ENDIF

        IFDEF Part4
        INCLUDE INSTMAC4.ASM
        ENDIF

        IFDEF Part5
        INCLUDE INSTMAC5.ASM
        ENDIF

        IFDEF Part6
        INCLUDE INSTMAC6.ASM
        ENDIF

        IFDEF Part7
        INCLUDE INSTMAC7.ASM
        ENDIF

        IFDEF Part8
        INCLUDE INSTMAC8.ASM
        ENDIF

        IFDEF Part9
        INCLUDE INSTMAC9.ASM
        ENDIF

        IFDEF PartA
        INCLUDE INSTMACA.ASM
        ENDIF

        IFDEF PartB
        INCLUDE INSTMACB.ASM
        ENDIF

        IFDEF PartC
        INCLUDE INSTMACC.ASM
        ENDIF

        IFDEF PartD
        INCLUDE INSTMACD.ASM
        ENDIF

        IFDEF PartE
        INCLUDE INSTMACE.ASM
        ENDIF

        IFDEF PartF
        INCLUDE INSTMACF.ASM
        ENDIF


        ; Test for more than 64K code in module
        IF (Offset $ - Offset Start) GT (0FFFFH-100H)
        ERR
        ENDIF

Code    ENDS
        END Start
