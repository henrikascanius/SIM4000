;*****
;*****              RC8000 machine instructions, part 1
;*****
;**********************************************************************

        INCLUDE UCHEAD.ASM
        INCLUDE ADDRMACM.ASM

; is, ml, ms, xl, xs, pl, ps, kl, ks, sp

;**********************************************************************
;*****
;*****                       Monitor control:
;*****
;**********************************************************************

_is     MACRO wreg                      ; Store interrupt register
        mov     ebx,es:IR
        mov     ds:[eax*4],ebx
        incic
        ENDM

        MakeOp  is,31

;**********************************************************************

_ml     MACRO wreg                      ; Load mask register
        mov     ebx,ds:[eax*4]
        or      ebx,80000000H
        mov     es:IM,ebx
        incic
        ENDM

        MakeOp  ml,12

;**********************************************************************

_ms     MACRO wreg                      ; Store mask register


        mov     ebx,es:IM
        mov     ds:[eax*4],ebx
        incic
        ENDM

        MakeOp  ms,30

;**********************************************************************

_xl     MACRO wreg                      ; Load exception register
        LOCAL @@1

        mov     ebx,ds:[eax*4]
        jc      @@1                     ; jump on RH HW

        shl     ebx,11
        setc    ch
        shl     ebx,1
        setc    cl
        incic
@@1:
        shl     ebx,23
        setc    ch
        shl     ebx,1
        setc    cl
        incic
        ENDM

        MakeOp  xl,16


;**********************************************************************

_xs     MACRO wreg                      ; Store exception register
        LOCAL @@1

        jc      @@1                     ; jump on RH halfword store

        mov     ebx,ecx
        shl     bh,1
        add     bl,bh
        shl     ebx,30
        shr     ebx,10
        and     ds:[eax*4],RightHWMask
        or      ds:[eax*4],ebx
        incic
@@1:
        mov     ebx,ecx
        shl     bh,1
        add     bl,bh
        shl     ebx,30
        shr     ebx,22
        and     ds:[eax*4],LeftHWMask
        or      ds:[eax*4],ebx
        incic

        ENDM

        MakeOp  xs,27

;**********************************************************************

_pl     MACRO wreg                      ; Load protection register
        mov     ebx,ds:DWORD PTR [eax*4]; Provoke exception on address fault
        incic
        ENDM

        MakeOp  pl,28

;**********************************************************************

_ps     MACRO wreg                      ; Store protection register
        LOCAL @@1
                                        ; Protection not implemented.

        jc      @@1                     ; jump on RH halfword store

        and     ds:[eax*4],RightHWMask
        or      ds:DWORD PTR [eax*4],08000000H
        incic
@@1:
        and     ds:[eax*4],LeftHWMask
        or      ds:DWORD PTR [eax*4],00008000H
        incic

        ENDM

        MakeOp  ps,29

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

;**********************************************************************

_sp     MACRO wreg              ; Skip if no protection
                                ; Protection not implemented.

        mov     ebx,ds:DWORD PTR [eax*4]; Provoke exception on address fault
        add     esi,8
        FetchNext
        
        ENDM

        MakeOp  sp,21

Code ENDS
     END Start

