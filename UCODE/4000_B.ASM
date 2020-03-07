;**********************************************************************
;*****
;*****              RC8000 machine instructions, part 11
;*****
;**********************************************************************

        INCLUDE UCHEAD.ASM
        INCLUDE ADDRMACM.ASM
        INCLUDE FLUTIL2.ASM

; fm, fd

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


;**********************************************************************
;*****
;*****                    Floating point divide:
;*****
;**********************************************************************

_fd     MACRO wreg              ; Floating point divide, compat. version
        LOCAL @@1,@@2,@@3,@@4,@@5

        FetchFloat &wreg
        mov     ecx,eax         ; test for zero
        or      edi,edi
        jz      @@1

        mov     ecx,ebx
        or      ecx,esi
        jz      @@2
                                ; Both operands are <> 0
@@5:    shl     esi,1
        jno     @@4             ; jump if denom. not normalised
        rcr     esi,1           ; bring signbit back

        push    62
        fild    ss:WORD PTR [esp]
        push    edi
        push    eax
        fild    ss:QWORD PTR [esp]
        push    esi
        push    ebx
        fild    ss:QWORD PTR [esp]

        fdiv
        fscale
        fistp   ss:QWORD PTR [esp]

        sub     ebp,edx
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
@@3:    NormAndRoundFloat
        StoreFloat &wreg, edi,eax,ebp
        incic
@@2:
        ; divide by zero:
        mov     cx,100H
        pop     esi             ; pushed by FetchFloat
        SetFloatExc
        incic
@@1:
        mov     ecx,ebx
        or      ecx,esi
        jz      @@2
        jmp     @@3

        ; normalise denominator:
        ; An unnormalised denom. may cause overflow in the FISTP instr.
        ; To avoid this, normalisation is performed. Performance is not
        ; important, as this situation only arises caused by e.g.
        ; program faults.

@@4:    sub     edx,1 SHL 19    ; adjust exp.
        shl     ebx,1           
        adc     esi,0           ; move bit across regs
        jmp     @@5             ; try again

        ENDM

        MakeOp  fd,52



Code ENDS
     END Start

