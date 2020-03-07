;**********************************************************************
;*****
;*****            ADDRESS MACROS FOR SHIFT OPERATIONS
;*****
;**********************************************************************


; Addressing modes:
; 0:      displacement
; 1: ic  +displacement
; 2:    x+displacement
; 3: ic+x+displacement 
; 4:      displacement indirect
; 5: ic  +displacement indirect
; 6:    x+displacement indirect
; 7: ic+x+displacement indirect

; All address macros leaves effective address as an HWORD address in eax
; SF must indicate sign of eff. address.

amode0  MACRO 
        sar     eax,8
        ENDM


amode1  MACRO
        sar     eax,7
        add     eax,esi
        sar     eax,1
        ENDM


amode2  MACRO xreg
        add     eax,ds:[4*&xreg]        ; add Wx to eax
        sar     eax,8
        ENDM


amode3  MACRO xreg
        add     eax,ds:[4*&xreg]        ; add Wx to eax
        sar     eax,7
        add     eax,esi
        sar     eax,1
        ENDM


amode4  MACRO
        sar     eax,9
        CheckAddr2
        mov     eax,ds:[eax*4]
        sar     eax,8
        ENDM

amode5  MACRO
        sar     eax,7
        add     eax,esi
        sar     eax,2
        CheckAddr2
        mov     eax,ds:[eax*4]
        sar     eax,8
        ENDM

amode6  MACRO xreg
        add     eax,ds:[4*&xreg]        ; add Wx to eax
        sar     eax,9
        CheckAddr2
        mov     eax,ds:[eax*4]
        sar     eax,8
        ENDM

amode7  MACRO xreg
        add     eax,ds:[4*&xreg]        ; add Wx to eax
        sar     eax,7
        add     eax,esi
        sar     eax,2
        CheckAddr2
        mov     eax,ds:[eax*4]
        sar     eax,8
        ENDM


