;**********************************************************************
;*****
;*****              RC8000 machine instructions, part 6
;*****
;**********************************************************************

        INCLUDE UCHEAD.ASM
        INCLUDE ADDRMACI.ASM

; am, al, ac, ic, sh, sl, se, sn, so, sz

;**********************************************************************
;*****
;*****                       Address Handling
;*****
;**********************************************************************

_am     MACRO wreg              ; Address Modify
        incicam
        ENDM

        MakeOp  am,9

;**********************************************************************

_al     MACRO wreg              ; Address Load
        mov     ds:[&wreg*4],eax
        incic
        ENDM
        
        MakeOp  al,11

;**********************************************************************

_ac     MACRO wreg              ; Address Complement
        neg     eax
        mov     ds:[&wreg*4],eax
        intexs
        incic
        ENDM

        MakeOp  ac,33

;**********************************************************************
;*****
;*****                       Monitor control:
;*****
;**********************************************************************

;**********************************************************************

_ic     MACRO wreg              ; Clear interrupt bits
        not     eax
        and     es:IR,eax
        incic
        ENDM

        MakeOp  ic,47



;**********************************************************************
;*****
;*****                       Skip instructions
;*****
;**********************************************************************

_sh     MACRO wreg              ; Skip if register high
        LOCAL @@1        

        cmp     ds:[4*&wreg],eax
        jng     @@1
        add     esi,8
        FetchNext
@@1:
        incic
        
        ENDM

        MakeOp  sh,40

;**********************************************************************

_sl     MACRO wreg              ; Skip if register low
        LOCAL @@1        

        cmp     ds:[4*&wreg],eax
        jnl     @@1
        add     esi,8
        FetchNext
@@1:
        incic
        
        ENDM

        MakeOp  sl,41

;**********************************************************************

_se     MACRO wreg              ; Skip if register equal
        LOCAL @@1        

        cmp     ds:[4*&wreg],eax
        jne     @@1
        add     esi,8
        FetchNext
@@1:
        incic
        
        ENDM

        MakeOp  se,42

;**********************************************************************

_sn     MACRO wreg              ; Skip if register not equal
        LOCAL @@1        

        cmp     ds:[4*&wreg],eax
        je      @@1
        add     esi,8
        FetchNext
@@1:
        incic
        
        ENDM

        MakeOp  sn,43

;**********************************************************************

_so     MACRO wreg              ; Skip if register bits one
        LOCAL @@1        

        mov     ebx,eax
        and     eax,ds:[4*&wreg]
        cmp     eax,ebx
        jne     @@1
        add     esi,8
        FetchNext
@@1:
        incic
        
        ENDM

        MakeOp  so,44

;**********************************************************************

_sz     MACRO wreg              ; Skip if register bits zero
        LOCAL @@1        

        and     eax,ds:[4*&wreg]
        jnz     @@1
        add     esi,8
        FetchNext
@@1:
        incic
        
        ENDM

        MakeOp  sz,45


Code ENDS
     END Start

