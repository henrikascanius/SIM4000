;**********************************************************************
;*****
;*****              RC8000 machine instructions, part 7
;*****
;**********************************************************************

        INCLUDE ADDRMACS.ASM

; as, ls, ad, ld


;**********************************************************************
;*****
;*****                        Word shifts
;*****
;**********************************************************************

_as     MACRO   wreg            ; Shift word arithm.
        LOCAL @@1,@@2,@@3,@@4,@@ovf

        mov     ebx,ds:[&wreg*4]
        js      @@1             ; jump on neg. count
        cmp     eax,23
        jg      @@2             ; jump on count>23

        mov     cl,al
        shl     ds:DWORD PTR [&wreg*4],cl ; shift Wreg

        ; test for overflow
        mov     eax,ds:[&wreg*4]
        sar     eax,cl
        xor     cl,cl
        cmp     eax,ebx
        setnz   ch
        jnz     @@ovf

        incic
@@2:
        ; shift count > 23:
        xor     cx,cx
        mov     ds:DWORD PTR [&wreg*4],0
        or      ebx,ebx
        setnz   ch
        jnz     @@ovf
        jmp     @@4

@@ovf:  int     4
@@4:    incic

@@1:
        ; shift count < 0
        cmp     eax,-23
        jl      @@3             ; jump on count<-23

        neg     al
        mov     cl,al
        sar     ebx,cl
        xor     bl,bl
        mov     ds:[&wreg*4],ebx
        xor     cx,cx
        incic

@@3:
        ; shift count < -23
        sar     ebx,24
        xor     bl,bl
        mov     ds:[&wreg*4],ebx
        xor     cx,cx
        jmp     @@4

        ENDM

        MakeOp  as,36

;**********************************************************************

_ls     MACRO   wreg            ; Shift word logical
        LOCAL @@1,@@2,@@3

        js      @@1             ; jump on neg. count
        cmp     eax,23
        jg      @@2             ; jump on count>23

        mov     ebx,ecx         ; Save Ex
        mov     cl,al
        shl     ds:DWORD PTR [&wreg*4],cl ; shift Wreg
        mov     ecx,ebx
        incic

@@2:
        ; abs shift count > 23:
        mov     ds:DWORD PTR [&wreg*4],0
        incic

@@1:
        ; shift count < 0
        cmp     eax,-23
        jl      @@2             ; jump on count<-23

        mov     ebx,ecx         ; Save Ex
        neg     al
        mov     cl,al
        shr     ds:DWORD PTR [&wreg*4],cl
        and     ds:DWORD PTR [&wreg*4],0FFFFFF00H
        mov     ecx,ebx
        incic


        ENDM

        MakeOp  ls,38


;**********************************************************************
;*****
;*****                      Double word shifts
;*****
;**********************************************************************


_ad     MACRO   wreg            ; Shift double arithm.
        LOCAL @@1,@@2,@@3,@@4,@@l1,@@l2,@@ovf

        js      @@1             ; jump on neg. count
        jz      @@4
        cmp     eax,47
        jg      @@2             ; jump on count>47

        mov     ecx,eax
        xor     bh,bh

        mov     eax,ds:DWORD PTR [&wreg*4]
        LdWPre  edx,&wreg

@@l1:
        shl     edx,1
        seto    bl
        or      bh,bl
        shl     eax,1
        setc    bl
        or      dh,bl
        loop    @@l1            ; cx=0 at loop exit


        mov     ds:[&wreg*4],eax
        StWPre  &wreg,edx

        mov     ch,bh
        test    ch,1
        jnz     @@ovf
        incic

@@2:
        ; shift count > 47:
        xor     cx,cx
        LdWPre  ebx,wreg
        or      ebx,ds:DWORD PTR [&wreg*4]
        mov     ds:DWORD PTR [&wreg*4],0
        StWPre  &Wreg,0
        or      ebx,ebx
        setnz   ch
        jnz     @@ovf
        incic

@@ovf:  int     4
        incic

@@1:
        ; shift count < 0
        cmp     eax,-47
        jl      @@3             ; jump on count<-47

        neg     eax
        mov     ecx,eax

        mov     eax,ds:DWORD PTR [&wreg*4]
        LdWPre  edx,&wreg
        sar     edx,8

@@l2:
        sar     edx,1
        rcr     eax,1
        loop    @@l2            ; CX=0 on exit

        shl     edx,8
        StWPre  &wreg,edx
        xor     al,al
        mov     ds:[&wreg*4],eax
        incic
@@4:
        xor     cx,cx
        incic


@@3:
        ; shift count < -47
        LdWPre  ebx,&wreg
        sar     ebx,24
        xor     bl,bl
        mov     ds:[&wreg*4],ebx
        StWPre  &wreg,ebx
        xor     cx,cx
        incic

        ENDM

        MakeOp  ad,37

;**********************************************************************

_ld     MACRO   wreg            ; Shift double logical
        LOCAL @@1,@@2,@@3,@@4,@@l1,@@l2

        js      @@1             ; jump on neg. count
        jz      @@4
        mov     di,cx           ; Save Ex
        cmp     eax,47
        jg      @@2             ; jump on count>47

        mov     ecx,eax

        mov     eax,ds:DWORD PTR [&wreg*4]
        LdWPre  edx,&wreg

@@l1:
        shl     edx,1
        shl     eax,1
        setc    bl
        or      dh,bl
        loop    @@l1            ; cx=0 at loop exit

        mov     ds:[&wreg*4],eax
        StWPre  &wreg,edx
        mov     cx,di

        jmp     @@4

@@2:
        ; abs shift count > 47:
        mov     ds:DWORD PTR [&wreg*4],0
        StWPre  &Wreg,0
        jmp     @@4

@@1:
        ; shift count < 0
        cmp     eax,-47
        jl      @@2             ; jump on count<-47

        mov     di,cx           ; Save Ex
        neg     eax
        mov     ecx,eax

        mov     eax,ds:DWORD PTR [&wreg*4]
        LdWPre  edx,&wreg
        shr     edx,8

@@l2:
        shr     edx,1
        rcr     eax,1
        loop    @@l2            ; CX=0 on exit

        shl     edx,8
        StWPre  &wreg,edx
        xor     al,al
        mov     ds:[&wreg*4],eax
        mov     cx,di
@@4:
        incic

        ENDM

        MakeOp  ld,39

