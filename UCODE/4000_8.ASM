;**********************************************************************
;*****
;*****              RC8000 machine instructions, part 8
;*****
;**********************************************************************

        INCLUDE UCHEAD.ASM
        INCLUDE ADDRMACM.ASM

; nd

;**********************************************************************
;*****
;*****                       Normalize double:
;*****
;**********************************************************************


_nd     MACRO wreg              ; Normalize double
        LOCAL @@1,@@l2,@@l3,@@l4,@@l5,@@r2,@@r3,@@r4,@@r5

        LdWPre  ebx,&wreg
        jc      @@1

        ; ******************* Left HW : *********************

        or      ebx,ebx
        js      @@l2

        ; Reg >=0:
        mov     di,cx            ; Save Ex
        bsr     ecx,ebx
        jz      @@l3             ; jump on Reg=0
        neg     cl
        add     cl,30            ; Perform doubleword shift (count is <23)
        mov     edx,ds:[&wreg*4]
        shr     ebx,8
        shld    ebx,edx,cl
        shl     ebx,8
        StWPre  &wreg,ebx
        shl     edx,cl
        mov     ds:[wreg*4],edx
        
        ; Store neg. count in left hw:
        neg     ecx             
        shl     ecx,20
        and     ds:[eax*4],RightHWMask
        or      ds:[eax*4],ecx
        mov     cx,di            ; restore Ex
        incic

@@l3:
        ; MSW is 0
        mov     ebx,ds:[&wreg*4]
        bsr     ecx,ebx
        jz      @@l4
        neg     cl
        add     cl,31
        shr     ebx,1
        shl     ebx,cl
        mov     dl,bl
        xor     bl,dl
        StWPre  &wreg,ebx
        shl     edx,24
        mov     ds:[&wreg*4],edx

        add     cx,23           ; Save neg. shift count
        neg     cx
        shl     ecx,20
        and     ds:[eax*4],RightHWMask
        or      ds:[eax*4],ecx
        mov     cx,di            ; restore Ex
        incic


@@l4:        
        ; Operand = 0, left HW:
        and     ds:[eax*4],RightHWMask
        or      ds:[eax*4],80000000H
        incic

@@l2:
        ; Reg < 0:
        mov     di,cx            ; Save Ex
        not     ebx              ; invert
        xor     bl,bl
        bsr     ecx,ebx
        jz      @@l5             ; jump on Reg=-1
        not     ebx
        xor     bl,bl
        neg     cl
        add     cl,30            ; Perform doubleword shift (count is <23)
        mov     edx,ds:[&wreg*4]
        shr     ebx,8
        shld    ebx,edx,cl
        shl     ebx,8
        StWPre  &wreg,ebx
        shl     edx,cl
        mov     ds:[wreg*4],edx
        
        ; Store neg. count in left hw:
        neg     ecx             
        shl     ecx,20
        and     ds:[eax*4],RightHWMask
        or      ds:[eax*4],ecx
        mov     cx,di            ; restore Ex
        incic

@@l5:
        ; MSW is -1
        mov     ebx,ds:[&wreg*4]
        not     ebx
        bsr     ecx,ebx
        not     ebx
        neg     cl
        add     cl,31
        stc
        rcr     ebx,1           ; set MSB
        shl     ebx,cl
        mov     dl,bl
        xor     bl,dl
        StWPre  &wreg,ebx
        shl     edx,24
        mov     ds:[&wreg*4],edx

        add     cx,23           ; Save neg. shift count
        neg     cx
        shl     ecx,20
        and     ds:[eax*4],RightHWMask
        or      ds:[eax*4],ecx
        mov     cx,di            ; restore Ex
        incic

@@1:
        ; ******************* Right HW : *********************

        or      ebx,ebx
        js      @@r2

        ; Reg >=0:
        mov     di,cx            ; Save Ex
        bsr     ecx,ebx
        jz      @@r3             ; jump on Reg=0
        neg     cl
        add     cl,30            ; Perform doubleword shift (count is <23)
        mov     edx,ds:[&wreg*4]
        shr     ebx,8
        shld    ebx,edx,cl
        shl     ebx,8
        STWPre  &wreg,ebx
        shl     edx,cl
        mov     ds:[wreg*4],edx
        
        ; Store neg. count in left hw:
        neg     ecx             
        shl     ecx,20
        shr     ecx,12
        and     ds:[eax*4],LeftHWMask
        or      ds:[eax*4],ecx
        mov     cx,di            ; restore Ex
        incic

@@r3:
        ; MSW is 0
        mov     ebx,ds:[&wreg*4]
        bsr     ecx,ebx
        jz      @@r4
        neg     cl
        add     cl,31
        shr     ebx,1
        shl     ebx,cl
        mov     dl,bl
        xor     bl,dl
        STWPre  &wreg,ebx
        shl     edx,24
        mov     ds:[&wreg*4],edx

        add     cx,23           ; Save neg. shift count
        neg     ecx             
        shl     ecx,20
        shr     ecx,12
        and     ds:[eax*4],LeftHWMask
        or      ds:[eax*4],ecx
        mov     cx,di            ; restore Ex
        incic


@@r4:        
        ; Operand = 0, right HW:
        and     ds:[eax*4],LeftHWMask
        or      ds:[eax*4],80000H
        incic

@@r2:
        ; Reg < 0:
        mov     di,cx            ; Save Ex
        not     ebx              ; invert
        xor     bl,bl
        bsr     ecx,ebx
        jz      @@r5             ; jump on Reg=-1
        not     ebx
        xor     bl,bl
        neg     cl
        add     cl,30            ; Perform doubleword shift (count is <23)
        mov     edx,ds:[&wreg*4]
        shr     ebx,8
        shld    ebx,edx,cl
        shl     ebx,8
        STWPre  &wreg,ebx
        shl     edx,cl
        mov     ds:[wreg*4],edx
        
        ; Store neg. count in left hw:
        neg     ecx             
        shl     ecx,20
        shr     ecx,12
        and     ds:[eax*4],LeftHWMask
        or      ds:[eax*4],ecx
        mov     cx,di            ; restore Ex
        incic

@@r5:
        ; MSW is -1
        mov     ebx,ds:[&wreg*4]
        not     ebx
        bsr     ecx,ebx
        not     ebx
        neg     cl
        add     cl,31
        stc
        rcr     ebx,1
        shl     ebx,cl
        mov     dl,bl
        xor     bl,dl
        STWPre  &wreg,ebx
        shl     edx,24
        mov     ds:[&wreg*4],edx

        add     cx,23           ; Save neg. shift count
        neg     ecx             
        shl     ecx,20
        shr     ecx,12
        and     ds:[eax*4],LeftHWMask
        or      ds:[eax*4],ecx
        mov     cx,di            ; restore Ex
        incic

        ENDM
        
        MakeOp  nd,35

Code ENDS
     END Start

