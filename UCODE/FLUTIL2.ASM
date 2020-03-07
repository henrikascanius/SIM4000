;**********************************************************************
;*****
;*****                          FLUTIL2.ASM:
;*****
;*****              Macros for floating point handling
;*****                  "Full-compatible" version.
;*****
;*****
;**********************************************************************

SetFloatExc MACRO
        or      S8.IR,20000000H         ; Set floating-point exception
        breakatfetch
        ENDM



;**********************************************************************
; FetchFloat:
;       Memory operand: Mantissa -> esi:ebx      exponent -> edx[30..19]
;       WReg operand  : Mantissa -> edi:eax      exponent -> ebp[30..19]
; Mantissa left-adjusted


FetchFloat MACRO wreg
        LOCAL @@1

        push    esi             ; save IC
        mov     ebx,DS:DWORD PTR [eax*4]
        jnz     @@1
        mov     eax,4
@@1:    mov     esi,DS:DWORD PTR [eax*4-4]
        mov     edx,RightHWMask
        mov     ebp,edx
        and     edx,ebx
        xor     ebx,edx
        shl     edx,12
        sar     edx,1
        rol     ebx,8
        or      si,bx
        xor     bl,bl

        LdWPre  edi,&wreg
        mov     eax,DS:DWORD PTR [&wreg*4]
        and     ebp,eax
        xor     eax,ebp
        shl     ebp,12
        sar     ebp,1
        rol     eax,8
        or      di,ax
        xor     al,al

        ENDM


;**********************************************************************
; NormAndRoundFloat:
; Perform "Normalise and Round Floating" on edi:eax, ebp.
; OF must hold mantissa overflow condition.
; NB: Takes exponent in ebp[30..19] and leaves it in ebp[31..20].


NormAndRoundFloat MACRO
        LOCAL   @@1,@@2,@@3,@@4,@@5,@@6,@@7,@@8,@@9,@@10

@@1:    jno     @@2
        shrd    eax,edi,1       ; right shift normalise
        sar     edi,1
        xor     edi,80000000H   ; fix sign bit!!!
        add     ebp,1 SHL 19
        jmp     @@3

@@2:    and     eax,0FC000000H  ; Reduce to 38 bits
        mov     ecx,eax         ; test for zero result
        or      ecx,edi
        jnz     @@4

        mov     ebp,0C0000000H  ; zero result
        jmp     @@3

@@4:    shld    edi,eax,1
        jc      @@5             

@@6:    js      @@7             ; positive
        shl     eax,1
        sub     ebp,1 SHL 19
        shld    edi,eax,1
        jmp     @@6

@@5:    jns     @@7             ; negative
        shl     eax,1
        sub     ebp,1 SHL 19
        shld    edi,eax,1
        jmp     @@5

@@7:    rcr     edi,1           ; bring MSB back in place

@@3:    test    eax,08000000H   ; Test for rounding
        jz      @@8
        
        and     eax,0F0000000H
        add     eax,10000000H   ; round
        adc     edi,0
        jmp     @@1             ; goto again (overflow preserved from adc)

@@8:    
        and     eax,0F0000000H  ; clear xtra bits
        shl     ebp,1
        seto    ch              ; test for exponent overflow
        or      ch,ch
        jz      @@9
        SetFloatExc
@@9:    xor     cl,cl

        ENDM


;**********************************************************************
; NormAndRoundFloat:
; Perform "Normalise and Round Floating" on edi:eax, ebp.
; OF must hold mantissa overflow condition.
; NB: Takes exponent in ebp[30..19] and leaves it in ebp[31..20].
; "High-speed version", but slower in practice and therefore not used!!!


NormAndRoundFloat2 MACRO
        LOCAL   @@1,@@2,@@3,@@4,@@5,@@6,@@7,@@8,@@9,@@10,@@11

@@1:    jno     @@2
        shrd    eax,edi,1       ; right shift normalise
        sar     edi,1
        xor     edi,80000000H   ; fix sign bit!!!
        add     ebp,1 SHL 19
        jmp     @@3

@@2:    and     eax,0FC000000H  ; Reduce to 38 bits
        mov     ecx,eax         ; test for zero result
        or      ecx,edi
        jz      @@4

        shld    edi,eax,1
        jc      @@5             

        js      @@7             ; positive
        jz      @@10
        bsr     ecx,edi
        sub     cl,30
        neg     cl
        shl     eax,1
        shld    edi,eax,cl
        shl     eax,cl
        inc     cl
        shl     ecx,19
        sub     ebp,ecx
        jmp     @@3
@@10:
        shld    edi,eax,6       ; edi = 0
        xor     eax,eax
        bsr     ecx,edi
        sub     cl,30
        neg     cl
        shl     edi,cl
        add     cl,6
        shl     ecx,19
        sub     ebp,ecx
        jmp     @@3

@@5:    jns     @@7             ; negative
        not     edi
        bsr     ecx,edi
        jz      @@11
        not     edi
        sub     cl,30
        neg     cl
        shl     eax,1
        shld    edi,eax,cl
        shl     eax,cl
        inc     cl
        shl     ecx,19
        sub     ebp,ecx
        jmp     @@3
@@11:
        not     eax
        shld    edi,eax,6       ; edi = 0
        xor     eax,eax
        bsr     ecx,edi
        not     edi
        sub     cl,30
        neg     cl
        shl     edi,cl
        add     cl,6
        shl     ecx,19
        sub     ebp,ecx
        jmp     @@3

@@4:    mov     ebp,080000000H  ; zero result
        xor     ecx,ecx
        jmp     @@6

@@7:    rcr     edi,1           ; bring MSB back in place

@@3:    test    eax,08000000H   ; Test for rounding
        jz      @@8
        
        and     eax,0F0000000H
        add     eax,10000000H   ; round
        adc     edi,0
        jmp     @@1             ; goto again (overflow preserved from adc)

@@8:    
        and     eax,0F0000000H  ; clear xtra bits
        shl     ebp,1
        seto    ch              ; test for exponent overflow
        jno     @@9
        SetFloatExc
@@9:    xor     cl,cl
@@6:
        ENDM



;**********************************************************************
; StoreFloat:
; Store floating operand in M1:M2,E.
; All xtra bits must be 0.

StoreFloat MACRO wreg,M1,M2,E

        shrd    &M2,&M1,8
        shr     &E,12
        or      &M2,&E
        mov     DS:DWORD PTR [&wreg*4],&M2
        and     &M1,0FFFFFF00H
        StWPre  &wreg,&M1
        xor     edi,edi
        pop     esi             ; restore IC

        ENDM
