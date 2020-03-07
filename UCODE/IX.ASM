;**********************************************************************

_ix     MACRO wreg              ; Index
        LOCAL @@1,@@2,@@3
        
        mov     ebx,ds:[4*&wreg]; Fetch ix
        add     esi,4
        mov     ecx,[esi]     ; Fetch doperel,type
        mov     edx,ecx
        sar     edx,20
        add     edx,eax         ; edx:=base+doperel
        btr     edx,0           ; convert to word addr.
        btr     eax,0           ; do.

        shl     ecx,12
        sar     ecx,20          ; ecx:=type
        jle     @@1             ; jump if type<=0

        shl     ebx,cl          ; ix:=ix shift type
@@1:
        cmp     ebx,ds:[edx*2]
        jng     @@2             ; ix <= LB
        cmp     ebx,ds:[edx*2-4]
        jge     @@2             ; ix > UB

        add     ebx,ds:[eax*2]
        mov     ds:[4*&wreg],ebx; Wreg:=base+ix

        xor     ecx,ecx         ; Ex22:=Ex23:=0
        incic

@@2:    ; ix out of bounds:
        mov     cx,0101H
        test    S8.IM,20000000H ; Test floating exeception active
        jnz     @@3

        mov     ebx,ds:[edx*2-4]
        add     ebx,ds:[eax*2]
        mov     ds:[4*&wreg],ebx; Wreg:=base+UB
        incic

@@3:
        SetFloatExc
        incic

        ENDM

        MakeOp  ix,61

