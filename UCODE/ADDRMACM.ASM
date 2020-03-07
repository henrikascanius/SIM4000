;**********************************************************************
;*****
;*****        ADDRESS MACROS FOR MEMORY-REFERNCING OPERATIONS
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

; All address macros leaves effective address as an WORD address in eax
; ZF must indicate zero-condition of effective address (for doubleword op's)
; CF must contain LSB (for halfword op's)

amode0  MACRO 
        sar     eax,9
        ENDM


amode1  MACRO
        sar     eax,7
        add     eax,esi
        sar     eax,2
        ENDM


amode2  MACRO xreg
        add     eax,ds:[4*&xreg]        ; add Wx to eax
        sar     eax,9
        ENDM


amode3  MACRO xreg
        add     eax,ds:[4*&xreg]        ; add Wx to eax
        sar     eax,7
        add     eax,esi
        sar     eax,2
        ENDM


amode4  MACRO
        sar     eax,9
        mov     eax,ds:[eax*4]
        sar     eax,9
        ENDM

amode5  MACRO
        sar     eax,7
        add     eax,esi
        sar     eax,2
        mov     eax,ds:[eax*4]
        sar     eax,9
        ENDM

amode6  MACRO xreg
        add     eax,ds:[4*&xreg]        ; add Wx to eax
        sar     eax,9
        mov     eax,ds:[eax*4]
        sar     eax,9
        ENDM

amode7  MACRO xreg
        add     eax,ds:[4*&xreg]        ; add Wx to eax
        sar     eax,7
        add     eax,esi
        sar     eax,2
        mov     eax,ds:[eax*4]
        sar     eax,9
        ENDM


