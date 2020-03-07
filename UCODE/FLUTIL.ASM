;**********************************************************************
;*****
;*****              Macros for floating point handling.
;*****                      "8087"-version.
;*****
;*****
;**********************************************************************

SetFloatExc MACRO
        or      S8.IR,20000000H         ; Set floating-point exception
        breakatfetch
        ENDM



PushReal  MACRO Addr,PreAddr
        mov     ebx,ds:DWORD PTR [&Addr]
        mov     edx,ebx
        and     ebx,RightHWMask
        xor     edx,ebx
        shl     ebx,12
        sar     ebx,20
        sub     ebx,35
        push    ebx
        fild    ss:DWORD PTR [esp]

        mov     ebx,ds:DWORD PTR [&PreAddr]
        sar     ebx,8
        shrd    edx,ebx,20
        sar     ebx,20
        push    ebx
        push    edx
        fild    ss:QWORD PTR [esp]

        fscale                          
        fstp    st(1)                   ; The scale factor remains, remove it.
        add     esp,12

        ENDM



PopReal MACRO Addr,PreAddr
        LOCAL @@1,@@2

        ; 3: Check for zero result. Over/underflow in 80x87 cannot occur
        ;    (except for divide-by-zero, which is checked seperately). This
        ;    is because only one add/subtract/multiply/divide is performed
        ;    at a time. I.e. the result will either be zero, or a normal
        ;    result, where one of the two foremost bits in the fraction is 1.
        ; 4: Shift results to proper place.

        fxtract
        xor     ebx,ebx
        ftst
        fstsw   ax
        test    ah,40H
        setz    bl
        neg     ebx
        and     bx,3DC0H
        shl     ah,7
        or      bh,ah
        shl     ebx,16
        push    ebx
        push    0
        fadd    ss:QWORD PTR [esp]
        fxtract
        push    34
        fild    ss:WORD PTR [esp]
        fxch
        fscale
        fistp   ss:QWORD PTR [esp]
        fincstp
        ffree   st(7)
        faddp   st(1)                   ; add exponents
        fistp   ds:WORD PTR [&Addr]
        fwait

        xor     ecx,ecx
        mov     edi,ss:DWORD PTR [esp]
        mov     ebx,ss:DWORD PTR [esp+4]
        add     esp,12

        shld    ebx,edi,20
        mov     dx,1800H                ; exp. for zero, avoid overflow detect
        jz      @@1                     ; jump on zero result
        shl     ebx,8

        mov     dx,ds:WORD PTR [&Addr] ; get exponent

        ; special case normalise, -1:
        shld    ecx,ebx,2
        sub     cl,3
        setz    cl
        sub     dx,cx
        shl     ebx,cl

        shl     edi,20

        inc     edx                     ; 80x87 has one more bit before point
@@1:    shl     edx,19
        shl     edx,1                   ; Test for over/underflow on 12-bit exp.
        seto    ch
        shr     edx,12                  
        or      edx,edi
        xor     dl,dl
        mov     ds:DWORD PTR [&Addr],edx
        xor     bl,bl
        mov     ds:DWORD PTR [&PreAddr],ebx
        xor     edi,edi                 ; edi(31..16)=0 req. by common fetch logic
        xor     cl,cl

        ; test overflow exception
        or      ch,ch
        jz      @@2

        SetFloatExc

@@2:

        ENDM


