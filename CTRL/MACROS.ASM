;**********************************************************************
;*****
;*****                          MACROS.ASM
;*****  Assorted useful macros                      92-12-13 17:13 HJ 
;**********************************************************************

; Convert 8086 segment register value to a linear address

segadr  MACRO segr
        sub     eax,eax
        mov     ax,&segr
        shl     eax,4
        ENDM


; Convert an 8086 segment to a linear address in a segment desciptor

segcvt  MACRO   segr,segm
        segadr  segr
        mov     segm&.base_l,AX
        shr     eax,8
        mov     segm&.base_m,ah
        ENDM


