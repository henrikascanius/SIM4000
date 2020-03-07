;**********************************************************************
;*****
;*****              RC8000 machine instructions, part 2
;*****
;**********************************************************************

        INCLUDE UCHEAD.ASM
        INCLUDE ADDRMACM.ASM

; rl, rs, rx, dl, ds, ns

;**********************************************************************
;*****
;*****                       Register transfer
;*****
;**********************************************************************



;**********************************************************************

_rl     MACRO wreg              ; Register Load
        mov     ebx,ds:[eax*4]
        mov     ds:[&wreg*4],ebx
        incic
        ENDM

        MakeOp  rl,20


;**********************************************************************

_rs     MACRO wreg              ; Register Store
        mov     ebx,ds:[&wreg*4]
        mov     ds:[eax*4],ebx
        incic
        ENDM
        
        MakeOp  rs,23


;**********************************************************************

_rx     MACRO wreg              ; Register Exchange
        mov     ebx,ds:[eax*4]
        xchg    ds:[&wreg*4],ebx
        mov     ds:[eax*4],ebx
        incic
        ENDM

        MakeOp  rx,25

;**********************************************************************
;*****
;*****                    Double reg. load/store
;*****
;**********************************************************************


;**********************************************************************

_dl     MACRO wreg              ; Double Register Load
        LOCAL @@1
        mov     ebx,ds:[eax*4]
        mov     ds:[wreg*4],ebx
        dec     eax
        jl      @@1             ; jump if eff. addr = 0

        mov     ebx,ds:[eax*4]

        stWPre  &wreg,ebx
        incic

@@1:    mov     ebx,ds:[12]     ; EA=0, MSW is w3

     IF &wreg EQ 0
        mov     ds:[12],ebx     ; load w3
     ELSE
        mov     ds:[(&wreg-1)*4],ebx
     ENDIF
        incic

        ENDM

        MakeOp  dl,54

;**********************************************************************

_ds     MACRO   wreg            ; Double Register Store
        LOCAL @@1
        mov     ebx,ds:[wreg*4]
        mov     ds:[eax*4],ebx

        ldWPre  ebx,&wreg

        dec     eax
        jl      @@1             ; jump if eff. addr = 0

        mov     ds:[eax*4],ebx
        incic

@@1:    mov     ds:[12],ebx     ; store into w3
        incic

        ENDM

        MakeOp  ds,55

;**********************************************************************
;*****
;*****                    Normalise single:
;*****
;**********************************************************************

_ns     MACRO wreg              ; Normalise single
        LOCAL @@1,@@l2,@@l3,@@r2,@@r3

        mov     ebx,ds:[&wreg*4]
        jc      @@1

        ; ******************* Left HW : *********************

        or      ebx,ebx
        js      @@l2

        ; Reg >=0:
        mov     edx,ecx         ; Save Ex
        bsr     ecx,ebx
        jz      @@l3             ; jump on Reg=0
        neg     cl
        add     cl,30
        shl     ds:DWORD PTR [&wreg*4],cl ; Normalise operand
        
        ; Store neg. count in left hw:
        neg     ecx             
        shl     ecx,20
        and     ds:[eax*4],RightHWMask
        or      ds:[eax*4],ecx
        mov     ecx,edx         ; restore Ex
        incic

@@l3:
        ; Operand = 0, left HW:
        
        and     ds:[eax*4],RightHWMask
        or      ds:[eax*4],80000000H
        incic

@@l2:
        ; Reg < 0:
        not     ebx             ; invert operand
        mov     edx,ecx         ; Save Ex
        bsr     ecx,ebx
        neg     cl
        add     cl,30
        shl     ds:DWORD PTR [&wreg*4],cl          ; Normalise operand
        
        ; Store neg. count in left hw:
        neg     ecx             
        shl     ecx,20
        and     ds:[eax*4],RightHWMask
        or      ds:[eax*4],ecx
        mov     ecx,edx         ; restore Ex
        incic

@@1:
        ; ******************* Right HW : *********************
        or      ebx,ebx
        js      @@r2

        ; Reg >=0:
        mov     edx,ecx         ; Save Ex
        bsr     ecx,ebx
        jz      @@r3             ; jump on Reg=0
        neg     cl
        add     cl,30
        shl     ds:DWORD PTR [&wreg*4],cl ; Normalise operand
        
        ; Store neg. count in left hw:
        neg     ecx             
        shl     ecx,20
        shr     ecx,12
        and     ds:[eax*4],LeftHWMask
        or      ds:[eax*4],ecx
        mov     ecx,edx         ; restore Ex
        incic

@@r3:
        ; Operand = 0, left HW:
        
        and     ds:[eax*4],LeftHWMask
        or      ds:[eax*4],80000H
        incic

@@r2:
        ; Reg < 0:
        not     ebx             ; invert operand
        mov     edx,ecx         ; Save Ex
        bsr     ecx,ebx
        neg     cl
        add     cl,30
        shl     ds:DWORD PTR [&wreg*4],cl          ; Normalise operand
        
        ; Store neg. count in left hw:
        neg     ecx             
        shl     ecx,20
        shr     ecx,12
        and     ds:[eax*4],LeftHWMask
        or      ds:[eax*4],ecx
        mov     ecx,edx         ; restore Ex
        incic

        ENDM
        
        MakeOp  ns,34


Code ENDS
     END Start


