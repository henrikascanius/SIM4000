;**********************************************************************
;*****
;*****              RC8000 machine instructions, part 4
;*****
;**********************************************************************

        INCLUDE UCHEAD.ASM
        INCLUDE ADDRMACM.ASM

; hl, hs, zl, el, ea, es
;**********************************************************************
;*****
;*****                      Halfword load/store
;*****
;**********************************************************************


_hl     MACRO wreg              ; Half Load
        LOCAL @@1
        mov     ebx,ds:[eax*4]
        mov     eax,ds:[&wreg*4]
        jc      @@1             ; jump on odd address
                                ; load left hw:
        and     ebx,LeftHWMask;
        shr     eax,20
        shrd    ebx,eax,12
        mov     ds:[&wreg*4],ebx
        incic
                                ; load right hw:
@@1:    and     ebx,RightHWMask
        and     eax,LeftHWMask
        or      eax,ebx
        mov     ds:[&wreg*4],eax
        incic
        ENDM

        MakeOp  hl,3

;**********************************************************************
        
_hs     MACRO wreg              ; Half Store
        LOCAL @@1
        mov     ebx,ds:[&wreg*4]
        mov     edx,ds:[eax*4]
        jc      @@1
                                ; store into left hw:
        and     edx,RightHWMask
        shl     ebx,12
        or      ebx,edx
        mov     ds:[eax*4],ebx
        incic
                                ; store into right hw:
@@1:    and     edx,LeftHWMask
        and     ebx,RightHWMask
        or      ebx,edx
        mov     ds:[eax*4],ebx
        incic
        ENDM

        MakeOp  hs,26

;**********************************************************************
;*****
;*****                      Halfword arithmetic
;*****
;**********************************************************************

_zl     MACRO   wreg            ; Load hw w. zero extension
        LOCAL @@1
        mov     ebx,ds:[eax*4]
        jc      @@1
                                ; load left hw:
        and     ebx,LeftHWMask
        shr     ebx,12
        mov     ds:[&wreg*4],ebx
        incic
                                ; load right hw:
@@1:    and     ebx,RightHWMask
        mov     ds:[&wreg*4],ebx
        incic

        ENDM        

        MakeOp  zl,19

;**********************************************************************

_el     MACRO wreg              ; load hw w. sign extension
        LOCAL @@1
        mov     ebx,ds:[eax*4]
        jc      @@1
                                ; load left hw:
        and     ebx,LeftHWMask
        sar     ebx,12
        mov     ds:[&wreg*4],ebx
        incic
                                ; load right hw:
@@1:    shl     ebx,12
        sar     ebx,12
        mov     ds:[&wreg*4],ebx
        incic

        ENDM        

        MakeOp  el,2

;**********************************************************************

_ea     MACRO   wreg            ; add hw
        LOCAL @@1
        mov     ebx,ds:[eax*4]
        jc      @@1
                                ; load left hw:
        and     ebx,LeftHWMask
        sar     ebx,12
        add     ds:[&wreg*4],ebx
        intexa
        incic
                                ; load right hw:
@@1:    shl     ebx,12
        sar     ebx,12
        add     ds:[&wreg*4],ebx
        intexa
        incic

        ENDM        

        MakeOp  ea,18

;**********************************************************************

_es     MACRO   wreg            ; subtract hw
        LOCAL @@1
        mov     ebx,ds:[eax*4]
        jc      @@1
                                ; load left hw:
        and     ebx,LeftHWMask
        sar     ebx,12
        sub     ds:[&wreg*4],ebx
        intexs
        incic
                                ; load right hw:
@@1:    shl     ebx,12
        sar     ebx,12
        sub     ds:[&wreg*4],ebx
        intexs
        incic

        ENDM        

        MakeOp  es,17

;**********************************************************************

Code ENDS
     END Start

