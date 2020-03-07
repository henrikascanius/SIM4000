;**********************************************************************
;*****
;*****              RC8000 machine instructions, part 15
;*****
;**********************************************************************

        INCLUDE UCHEAD.ASM
        INCLUDE ADDRMACM.ASM

; rl, rs, rx, kl, ks

;**********************************************************************

_rl     MACRO wreg              ; Register Load
        mov     ebx,ds:[eax*4]
        mov     ds:[&wreg*4],ebx
        incic
        ENDM

        MakeOp  rl,20


;**********************************************************************

_rs     MACRO wreg              ; Register Store
        mov     ebx,ds:[&wreg*4]
        mov     ds:[eax*4],ebx
        incic
        ENDM
        
        MakeOp  rs,23


;**********************************************************************

_rx     MACRO wreg              ; Register Exchange
        mov     ebx,ds:[eax*4]
        xchg    ds:[&wreg*4],ebx
        mov     ds:[eax*4],ebx
        incic
        ENDM

        MakeOp  rx,25

;**********************************************************************

_kl     MACRO wreg                      ; Load protection key
                                        ; Protection not implemented.
        mov     ebx,ds:DWORD PTR [eax*4]; Provoke exception on address fault
        mov     ds:DWORD PTR [&wreg*4],0
        incic
        ENDM

        MakeOp  kl,22

;**********************************************************************

_ks     MACRO wreg                      ; Store protection key
                                        ; Protection not implemented.
        mov     ebx,ds:DWORD PTR [eax*4]; Provoke exception on address fault
        incic
        ENDM

        MakeOp  ks,51

Code ENDS
     END Start

