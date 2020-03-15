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
        LOCAL @@1,@@l2,@@l3,@@l4,@@l5,@@l6,@@l7,@@l8,@@r2,@@r3,@@r4,@@r5,@@r6,@@r7,@@r8

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
        jmp     @@l7

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
        jmp     @@l6

@@l4:        
        ; Operand = 0, left HW:
        mov     ecx,80000000H
        jmp     @@l8

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
@@l7:        
        neg     ecx
@@l6:        
        shl     ecx,20
@@l8:        
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
        jmp     @@l6

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
        jmp     @@r7

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
        jmp     @@r6

@@r4:        
        ; Operand = 0, right HW:
        mov     ecx,80000000H
        jmp     @@r8

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
@@r7:        
        neg     ecx
@@r6:        
        shl     ecx,20
@@r8:        
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
        jmp     @@r7

        ENDM
        
        MakeOp  nd,35

Code ENDS
     END Start

