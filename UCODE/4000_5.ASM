;**********************************************************************
;*****
;*****              RC8000 machine instructions, part 5
;*****
;**********************************************************************

        INCLUDE UCHEAD.ASM
        INCLUDE ADDRMACM.ASM

; jl, jd, je, la, lo, lx


;**********************************************************************
;*****
;*****                       Jump instructions
;*****
;**********************************************************************

_jl     MACRO wreg              ; Jump w. register link

        mov     ebx,ds:[eax*4]  ; test address
     IF &wreg NE 0
        add     esi,4
        shl     esi,7
        mov     ds:[wreg*4],esi
     ENDIF
        
        shl     eax,2
        mov     esi,eax
        FetchNext
        
        ENDM

        MakeOp  jl,13

;**********************************************************************

_jd     MACRO wreg              ; Jump disabled 

        mov     ebx,ds:[eax*4]  ; test address
     IF &wreg NE 0
        add     esi,4
        shl     esi,7
        mov     ds:[wreg*4],esi
     ENDIF
        
        shl     eax,2
        mov     esi,eax
        mov     S8.IntEn,0
        FetchNext
        
        ENDM

        MakeOp  jd,14

;**********************************************************************

_je     MACRO wreg              ; Jump enabled

        mov     ebx,ds:[eax*4]  ; test address
     IF &wreg NE 0
        add     esi,4
        shl     esi,7
        mov     ds:[wreg*4],esi
     ENDIF
        
        shl     eax,2
        mov     esi,eax
        mov     S8.IntEn,1
        BreakAtFetch
        FetchNext
        
        ENDM

        MakeOp  je,15

;**********************************************************************
;*****
;*****                      Integer word logic
;*****
;**********************************************************************

_la     MACRO   wreg            ; Logical and
        mov     ebx,ds:[eax*4]
        and     ds:[4*&wreg],ebx
        incic
        ENDM

        MakeOp  la,4

;**********************************************************************

_lo     MACRO   wreg            ; Logical or
        mov     ebx,ds:[eax*4]
        or      ds:[4*&wreg],ebx
        incic
        ENDM

        MakeOp  lo,5

;**********************************************************************

_lx     MACRO   wreg            ; Logical xor
        mov     ebx,ds:[eax*4]
        xor     ds:[4*&wreg],ebx
        incic
        ENDM

        MakeOp  lx,6


;**********************************************************************


Code ENDS
     END Start

