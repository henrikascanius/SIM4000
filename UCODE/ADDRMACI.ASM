

; Addressing modes:
; 0:      displacement
; 1: ic  +displacement
; 2:    x+displacement
; 3: ic+x+displacement 
; 4:      displacement indirect
; 5: ic  +displacement indirect
; 6:    x+displacement indirect
; 7: ic+x+displacement indirect

; All address macros leaves effective address as a operand in eax
; ZF must indicate zero-condition of effective address (for doubleword op's)

amode0  MACRO 
        ENDM


amode1  MACRO
        mov     ebx,esi
        shl     ebx,7                   ; make IC an operand
        add     eax,ebx
        ENDM


amode2  MACRO xreg
        add     eax,ds:[4*&xreg]        ; add Wx to eax
        ENDM


amode3  MACRO xreg
        amode1
        amode2 &xreg
        ENDM


amode4  MACRO
        sar     eax,9
        mov     eax,ds:[eax*4+0]
        ENDM

amode5  MACRO
        amode1
        amode4
        ENDM

amode6  MACRO xreg
        amode2 &xreg
        amode4
        ENDM

amode7  MACRO xreg
        amode3 &xreg
        amode4
        ENDM


