;**********************************************************************
;*****
;*****              RC8000 machine instructions, part 3
;*****
;**********************************************************************

        INCLUDE ADDRMACM.ASM

; wa, ws, wm, wd, aa, ss


;**********************************************************************
;*****
;*****                    Integer word arithmetic
;*****
;**********************************************************************

_wa     MACRO   wreg            ; Word Add
        mov     ebx,ds:[eax*4]
        add     ds:[4*&wreg],ebx
        intexa
        incic
        ENDM

        MakeOp  wa,7

;**********************************************************************

_ws     MACRO   wreg            ; Word Subtract
        mov     ebx,ds:[eax*4]
        sub     ds:[4*&wreg],ebx
        intexs
        incic
        ENDM

        MakeOp  ws,8

;**********************************************************************

_wm     MACRO   wreg            ; Word Multiply
        mov     eax,ds:[eax*4]
        imul    ds:dword ptr[4*&wreg]
        shrd    eax,edx,8
        mov     ds:[4*&wreg],eax
        xor     dl,dl

        stWPre  &wreg,edx

        incic
        ENDM

        MakeOp  wm,10

;**********************************************************************

_wd     MACRO   wreg            ; Word Divide
        LOCAL @@1,@@2

        xor     cx,cx           ; set ex(22:23) to 0
        mov     ebx,ds:[eax*4]
        sar     ebx,8

        mov     eax,ds:[&wreg*4]
        LdWPre  edx,&wreg

        sar     edx,8
        shrd    eax,edx,8
        sar     edx,8
        idiv    ebx             ; if int0 occurs, CH is set by int. handler
        or      ch,ch
        jnz     @@2

        shld    ebx,eax,8
        shl     eax,8
        sets    bh
        add     bl,bh
        jnz     @@1             ; jump on overflow

        mov     ds:[&wreg*4],eax
        shl     edx,8
        stWPre  &wreg,edx
        incic
@@1:
        mov     ch,1            ; set overflow
        int     4               ; make overflow
@@2:
        incic

        ENDM

        MakeOp  wd,24

;**********************************************************************
;*****
;*****                Integer Double Word Arithmetic
;*****
;**********************************************************************

_aa     MACRO   wreg            ; Add integer double word
        LOCAL @@1
        mov     ebx,ds:[eax*4]
        dec     eax
        jl      @@1             ; jump if EA is 0

        add     ds:[&wreg*4],ebx
        mov     ebx,0
        setc    bh
        add     ebx,ds:[eax*4]

     IF &wreg EQ 0
        add     ds:[12],ebx     ; add to w3
     ELSE
        add     ds:[(&wreg-1)*4],ebx
     ENDIF

        intexa
        incic

@@1:    add     ds:[&wreg*4],ebx
        mov     ebx,0
        setc    bh
        add     ebx,ds:[12]

     IF &wreg EQ 0
        add     ds:[12],ebx     ; add to w3
     ELSE
        add     ds:[(&wreg-1)*4],ebx
     ENDIF

        intexa
        incic

        ENDM

        MakeOp  aa,56

;**********************************************************************

_ss     MACRO   wreg            ; Subtract double word
        LOCAL @@1
        mov     ebx,ds:[eax*4]
        dec     eax
        jl      @@1             ; jump if EA is 0

        sub     ds:[&wreg*4],ebx
        mov     ebx,0
        setc    bh
        add     ebx,ds:[eax*4]

     IF &wreg EQ 0
        sub     ds:[12],ebx     ; subtr. from w3
     ELSE
        sub     ds:[(&wreg-1)*4],ebx
     ENDIF

        intexs
        incic

@@1:    sub     ds:[&wreg*4],ebx
        mov     ebx,0
        setc    bh
        add     ebx,ds:[12]

     IF &wreg EQ 0
        sub     ds:[12],ebx     ; subtr. from w3
     ELSE
        sub     ds:[(&wreg-1)*4],ebx
     ENDIF

        intexs
        incic

        ENDM

        MakeOp  ss,57


