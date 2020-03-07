;**********************************************************************
;*****
;*****              RC8000 machine instructions, part 10
;*****
;**********************************************************************

        INCLUDE UCHEAD.ASM
        INCLUDE ADDRMACM.ASM
        INCLUDE FLUTIL2.ASM

; fs

;**********************************************************************
;*****
;*****                 Floating point subtract:
;*****
;**********************************************************************


_fs     MACRO wreg              ; Floating point subtract
        LOCAL @@1,@@2,@@3,@@4,@@5,@@6,@@7

        FetchFloat &wreg

        mov     ecx,ebp
        sub     ecx,edx         ; SC := Wexp - SBexp
        cmp     ecx,38 SHL 19
        jl      @@1 
        shl     ebp,1
        xor     ecx,ecx
        StoreFloat &wreg, edi,eax,ebp
        incic
;        jmp     @@7
@@1:
        cmp     ecx,(-38) SHL 19
        jg      @@2
        mov     ebp,edx         ; Wexp := SBexp
        xor     eax,eax
        xor     edi,edi         ; AF := 0
        jmp     @@5
@@2:
        or      ecx,ecx
        js      @@3

        shr     ecx,19          ; 38>ecx>=0, shift mem-op. right
        cmp     cl,16
        jl      @@4
        shrd    ebx,esi,16
        sar     esi,16
        sub     cl,16
@@4:    shrd    ebx,esi,cl
        sar     esi,cl
        jmp     @@5
@@3:
        neg     ecx             ; -38<ecx<0, shift w-op. right
        mov     ebp,edx         ; Wexp := SBexp
        shr     ecx,19          
        cmp     cl,16
        jl      @@6
        shrd    eax,edi,16
        sar     edi,16
        sub     cl,16
@@6:    shrd    eax,edi,cl
        sar     edi,cl
@@5:
        sub     eax,ebx
        sbb     edi,esi

        NormAndRoundFloat
@@7:    StoreFloat &wreg, edi,eax,ebp
        incic

        ENDM

        MakeOp  fs,49



Code ENDS
     END Start

