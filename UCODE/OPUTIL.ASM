;**********************************************************************
;*****
;*****             Common macros etc. for RC8000 instructions
;*****
;**********************************************************************



LeftHWMask      EQU     0FFF00000H
RightHWMask     EQU     000FFF00H




intexa  MACRO                   ; Std. handling of ex(22:23), addition
        setc    cl
        seto    ch
        into
        ENDM


intexs  MACRO                   ; Std. handling of ex(22:23), subtraction
        setnc   cl              ; 80386 indicates borrow, RC8000 indic. carry
        seto    ch
        into
        ENDM

ldWPre  MACRO   reg,wreg
     IF &wreg EQ 0
        mov     &reg,ds:DWORD PTR [12]    ; load w3
     ELSE
        mov     &reg,ds:DWORD PTR[(&wreg-1)*4]
     ENDIF
        ENDM

stWPre  MACRO   wreg,reg
     IF &wreg EQ 0
        mov     ds:DWORD PTR [12],&reg     ; store w3
     ELSE
        mov     ds:DWORD PTR [(&wreg-1)*4],&reg
     ENDIF
        ENDM


FetchNext MACRO
        mov     eax,[esi]
        rol     eax,12
        mov     di,ax
        sar     eax,12                  ; place D-field as operand in EAX
        jmp     gs:DWORD PTR Optable[edi*4]
        ENDM



incic   MACRO                           ; increment IC
        add     esi,4
        FetchNext
        ENDM

incicam MACRO                           ; increment IC
        add     esi,4
        mov     ebx,eax
        mov     eax,[esi]
        rol     eax,12
        mov     di,ax
        sar     eax,12                  ; place D-field as operand in EBX
        add     eax,ebx                 ; add to EA of prev. am instr.
        jmp     cs:DWORD PTR Optable[edi*4]
        ENDM


breakatfetch MACRO                      ; set breakpoint for interrupts
        cli
        push    BreakSeg
        pop     gs
        sti
        ENDM


CheckAddr MACRO
       LOCAL @@1
       pushf
       cmp eax,S8.CoreWords
       jb  @@1
       popf
       jmp cs:dword ptr Optable[4004H]
@@1:   popf
       ENDM

CheckAddr2 MACRO
       LOCAL @@1
       cmp eax,S8.CoreWords
       jb  @@1
       jmp cs:dword ptr Optable[4004H]
@@1:   
       ENDM
