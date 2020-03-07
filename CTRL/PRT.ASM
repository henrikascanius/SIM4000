lptportbase EQU 278h


printc  PROC

        push    cx
        push    bx
        push    dx
        mov     dx,lptportbase+0
        out     dx,al
        mov     bl,10h
        sub     cx,cx
        inc     dx
busyl:
        in      al,dx
        test    al,80h
        jnz     strobe
        loop    busyl
        dec     bl
        jnz     busyl
strobe:
        mov     al,0dh
        inc     dx
        out     dx,al
        mov     cx,500
signl:
        push    ax
        pop     ax
        loop    signl
        dec     al
        out     dx,al
        pop     dx
        pop     bx
        pop     cx
        ret

printc  ENDP


hexit   PROC
; print hex digit

        or      al,30h
        cmp     al,3ah
        jl      yes1
        add     al,7
yes1:
        call    printc
        ret

hexit   ENDP


prtalx  PROC
; print hex byte

        push    ax
        shr     al,4
        call    hexit
        pop     ax
        push    ax
        and     al,0fh
        call    hexit 
        pop     ax
        ret

prtalx  ENDP


prtaxx  PROC
; print hex word

        push    ax
        push    ax
        mov     al,ah
        call    prtalx
        pop     ax
        call    prtalx
        pop     ax
        ret

prtaxx  ENDP


prteaxx PROC
; print hex dword

        push    eax
        push    eax
        shr     eax,16
        call    prtaxx
        pop     eax
        call    prt16
        pop     eax
        ret

prteaxx ENDP

prt16   PROC
; print ax fol. by space

        call    prtaxx
        mov     al,' '
        call    printc
        ret

prt16   ENDP


newln   PROC
; print crlf

        push    ax
        mov     al,0dh
        call    printc
        mov     al,0ah
        call    printc
        pop     ax
        ret

newln   ENDP

