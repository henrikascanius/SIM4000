;**********************************************************************
;*****
;*****              RC8000 machine instructions, part 13
;*****
;**********************************************************************

; sp, fd

        INCLUDE UCHEAD.ASM
        INCLUDE ADDRMACM.ASM
        INCLUDE FLUTIL2.ASM


;**********************************************************************

_sp     MACRO wreg              ; Skip if no protection
                                ; Protection not implemented.

        mov     ebx,ds:DWORD PTR [eax*4]; Provoke exception on address fault
        add     esi,8
        FetchNext
        
        ENDM

        MakeOp  sp,21

;**********************************************************************
;*****
;*****               Floating point multiply:
;*****
;**********************************************************************

_fm     MACRO wreg              ; Floating point multiply

        FetchFloat   &wreg
        push    -64
        fild    ss:WORD PTR [esp]
        push    esi
        push    ebx
        fild    ss:QWORD PTR [esp]
        push    edi
        push    eax
        fild    ss:QWORD PTR [esp]

        fmul
        fscale
        fistp   ss:QWORD PTR [esp]

        add     ebp,edx
        fwait
        ffree   st(1)
        
        pop     eax
        pop     edi
        add     esp,12
        shl     edi,1
        pushf
        shl     eax,1
        adc     edi,0
        popf
        NormAndRoundFloat
        StoreFloat &wreg, edi,eax,ebp
        incic

        ENDM

        MakeOp  fm,50


Code ENDS
     END Start

