;**********************************************************************
;*****
;*****              RC8000 machine instructions, part 9
;*****
;**********************************************************************

        INCLUDE ADDRMACS.ASM

; ci, cf

;**********************************************************************
;*****
;*****                       Conversion:
;*****
;**********************************************************************

_ci     MACRO wreg              ; Convert integer to floating
        LOCAL @@2,@@3,@@4

        mov     ebx,ds:[&wreg*4]

        or      ebx,ebx
        js      @@2

        ; Reg >=0:
        bsr     ecx,ebx
        jz      @@3              ; jump on Reg=0
        neg     cl               
        add     cl,30
        shl     ebx,cl           ; Normalise operand
        StWPre  &wreg,ebx

        ; calc. exponent:
        neg     cl               
        add     cl,23
        add     eax,ecx         ; will never overflow in 32-bit
        mov     ebx,eax
        shl     eax,20
        shr     eax,12
        mov     ds:[wreg*4],eax ; save exp. part

        ; test overflow:
        xor     cx,cx
        shl     eax,12
        sar     eax,20
        cmp     eax,ebx
        setnz   ch
        jnz     @@4             ; jump on overflow

        incic

@@4:
        ; overflow:
        int     4
        incic

@@3:
        ; operand = 0:
        StWPre  &wreg,0
        mov     ds:[&wreg*4],00080000H
        xor     ecx,ecx
        incic

@@2:
        ; Reg < 0:

        not     ebx
        bsr     ecx,ebx
        not     ebx
        neg     cl               
        add     cl,30
        shl     ebx,cl           ; Normalise operand
        StWPre  &wreg,ebx

        ; calc. exponent:
        neg     cl               
        add     cl,23
        add     eax,ecx         ; will never overflow in 32-bit
        mov     ebx,eax
        shl     eax,20
        shr     eax,12
        mov     ds:[wreg*4],eax ; save exp. part

        ; test overflow:
        xor     cx,cx
        shl     eax,12
        sar     eax,20
        cmp     eax,ebx
        setnz   ch
        jnz     @@4             ; jump on overflow

        incic


        ENDM
        
        MakeOp  ci,32

;**********************************************************************

_cf     MACRO wreg              ; Convert floating to integer
        LOCAL @@1,@@2,@@3,@@4

        mov     ebx,ds:[&wreg*4]
        LdWPre  edx,&wreg
        mov     ecx,RightHWMask
        and     ecx,ebx
        xor     ebx,ecx         ; separate exp. part in edx
        jnz     @@1             ; jump if 12 LSB of mantissa <> 0

        or      edx,edx         ; test MS part of fraction
        jz      @@2             ; zero result


@@1:
        shl     ecx,12
        sar     ecx,20
        neg     ecx
        sub     ecx,eax
        add     ecx,23
        js      @@3             ; jump on overflow (assuming normalised 
                                ; operand; RC4000 does it so).
        sar     edx,8
        cmp     ecx,31
        jg      @@2             ; certainly zero!
@@4:
        shl     ebx,1           ; get "bit 24" into carry (if CL=0)
        sar     edx,cl
        adc     edx,0           ; rounding
        shl     edx,7
        shl     edx,1           ; overflow detect only w. shift count = 1
        jo      @@3

        mov     ds:[&wreg*4],edx ; store
        xor     ecx,ecx         ; no overflow
        incic

@@2:
        ; result is 0:
        mov     ds:DWORD PTR [&wreg*4],0
        xor     ecx,ecx
        incic

@@3:
        ; overflow:
        mov     cx,100H
        int     4
        incic

        ENDM
        
        MakeOp  cf,53


