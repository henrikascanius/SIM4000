
        MASM

        assume cs:code, ds:data

        extrn   tentry: word
        extrn   prtab:  byte
        extrn   pagem:  byte
        extrn   protm:  byte
        extrn   cpos:   word
        extrn   wrap:   byte
        extrn   scrstate:word
        extrn   keytab: byte


data    ends



code    segment public


kbtbl   db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 3, 4, 6,23
        db       25,12,14,15,18, 0, 0,17,19, 7, 0, 8, 0,24, 0,22
        db       20,11, 5,127,26,29,30,31,2,10,16, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0


        ; Table 1: Tailored for RC8000 Data Entry System
        ; Right- and down-arrows switched around; up-arrow sends 25 dec.

        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 3, 4, 6,23
        db       25,12,14,15,18, 0, 0,17,25, 7, 0, 8, 0, 9, 0,22
        db       24,11, 5,127,26,29,30,31,2,10,16, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0


        ; Table 2: Tailored for RC8000 Screen Editor.
        ; Home-key sends 05 dec.

        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 3, 4, 6,23
        db       25,12,14,15,18, 0, 0,05,19, 7, 0, 8, 0,24, 0,22
        db       20,11, 5,127,26,29,30,31,2,10,16, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        db        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0



keybdin endp


rc851   proc near
        ; RC851 emulator for IBM PC.
        ; Called with databyte as parameter in BX. Return value: 0, unless
        ; the sequence 'ESC' <char> is received, in which case the
        ; value of <char> is returned.

        cmp     bx,31
        jg      tnorm                   ; jump if not ctrl. char

                                        ; ctrl char:
        shl     bl,1                    ;
        jmp     cs:word ptr tctr[bx]    ; case char of...

                                        ; normal (visible) char:
tnorm:  cmp     bl,127                  ; char='DEL'?
        je      texit                   ; yes, skip
        push    bx
        cmp     protm,0
        jnz     tnn                     ; jump if unprot.
        
        mov     ax,0920H
        mov     bl,protatt
        xor     bh,bh
        mov     cx,1
        int     10H                     ; set attr. for protected char

tnn:    call    consout                 ; char to console (char on stack)
        mov     bx,cpos
        mov     al,protm
        and     byte ptr prtab[bx],al   ; update screenmap
        and     pagem,al                ; update pagemode
        inc     bx                      ; update cursor pos.
        mov     cpos,bx
        mov     ax,bx                   ; check for wrap-around:
        mov     bl,80
        div     bl                      ; AL:=lineno (0..23); AH:=column (0..79)
        or      ah,ah                   ; new column=0 means 'line wrap'
        jz      twrap

        mov     wrap,0                  ; clear 'wrap'-flag
        call    tunpr                   ; search unprotected

texit:  xor     ax,ax                   ; exit: return value 0
        pop     bp
        ret     2                       ; return and unstack


twrap:  mov     wrap,1                  ; linewrap: set flag (affects 'LF' act.)
        cmp     pagem,0                 ; test pagemode
        jz      twrpr                   ; jump on pagemode wrap!

        cmp     cpos,1920               ; test for 'out of bottom' scroll
        jne     texit
        sub     cpos,80                 ; remain on line 23
        mov     ax,10
        push    ax
        call    consout                 ; send 'NL' to scroll screen
        call    tunpr1                  ; put cursor back in place
        jmp     texit                   ; return

                                        ; wrap, pagemode:
twrpr:  cmp     al,24                   ; bottom line?
        jne     twrpr1
        mov     cpos,0                  ; yes, move to (0,0)
twrpr1: mov     bx,offset texit
        push    bx                      ; push offset texit
        jmp     tunpr1                  ; search unprot.
                                        ; end code for 'normal' chars




        ; routines for control char handling:

t05:    mov     ax,cpos                 ; chr(5): 'DELETE LINE' --------------
        mov     bl,80
        div     bl                      ; AL:=line; AH:=column
        mov     cl,ah
        xor     ch,ch
        sub     cpos,cx                 ; pos:=col. 0 on curr. line
        call    tunpr1                  ; search unprot.
                                        ; continue as 'EEOL'

t30:    call    tupdin                  ; init erase
        mov     ax,cpos                 ; chr(30): EEOL ----------------------
        mov     cl,80
        div     cl
        sub     cl,ah                   ; CL:=no.chrs. curr.pos - end of line
        xor     ch,ch
                                        ; the following code also used by 'EEOS'
                                        ; CX contains no. of positions in
                                        ; 'erase area'
tera:   mov     bx,cpos
        lea     di,prtab[bx]            ; map index to DI
t302:   mov     ax,ds
        mov     es,ax                   ; ES:=DS
        mov     al,32                   ; search key
        repne scasb                     ; search unprotected
        jne     texit1                  ; finished if not found

        mov     si,di
        dec     si                      ; SI:=ptr to first unprot. pos.
        mov     bx,cx                   ; save counter
        repe scasb                      ; search protected (or end of area)
        push    cx
        push    di
        jcxz    t301
        dec     di
t301:   sub     di,si
        mov     cx,di                   ; CX:=no. of chars to erase
        mov     ax,si
        lea     bx,prtab
        sub     ax,bx                   ; calc. startpos.
        mov     bl,80
        div     bl
        mov     dl,ah
        mov     dh,al                   ; startpos. in DX
        call    tupd                    ; update console buffer
        mov     ss,sss                  ; restore ss
        pop     di
        pop     cx
        jcxz    texit1                  ; repeat if not end of area
        jmp     t302

texit1: call    tupdfi
        jmp     texit
                                        ; end 'EEOL'



t06:    mov     tentry,offset t06a      ; chr(6): 'START ADDR' ---------------
        jmp     texit                   ; set new entrypoint and exit

t06a:   call    tcadd                   ; convert column no.
        mov     scrstate,bx             ; save
        mov     tentry,offset t06b      ; new entrypoint
        jmp     texit

t06b:   call    tcadd                   ; convert lineno.
        mov     al,80
        mul     bl
        add     ax,scrstate             ; calc. pos
        cmp     ax,(1920-1)             ; test for ill. addr
        jle     t061
        xor     ax,ax                   ; fault: goto (0,0)
t061:   mov     cpos,ax
        mov     wrap,0                  ; clear wrapflag
        mov     tentry,offset rc851     ; restore entrypoint
        call    tunpr1                  ; move cursor
        jmp     texit                   ; exit

                                        ; subrout. to convert RC851
                                        ; addr. to int. repr:
tcadd:  mov     bl,byte ptr keytab[bx]  ; re-convert to ISO repr.
        sub     bl,96                   ; ...if BL>=96 then BL:=BL-96
        cmp     bl,(96-96-1)
        jg      tcaddx
        add     bl,64                   ;    else if BL>=65 then BL:=BL-32 else
        cmp     bl,(64-32-1)
        jg      tcaddx
        add     bl,64                   ;         BL:=BL+32;
tcaddx: ret
                                        ; end 'START ADDR'



t07:    cli                             ; chr(7): 'BEL' ----------------------
        mov     al,beepcnt
        add     al,beepdur              ; inc beeptime
        cmp     al,90                   ; limit at 5 sec.
        jle     t071
        mov     al,90
t071:   mov     beepcnt,al
        sti
        jmp     texit                   ; exit
                                        ; end 'BEL'



t08:    mov     ax,cpos                 ; chr(8): 'BS' -----------------------
        mov     bl,80
        div     bl                      ; test for column 0
        or      ah,ah
        jz      texit2                  ; no action if col. 0

        dec     cpos                    ; cursor 1 pos. right
        call    tunpr1                  ; move cursor
        jmp     texit                   ; exit
                                        ; end 'BS'



t09:    mov     wrap,0                  ; chr(9): 'TAB' ----------------------
        cmp     pagem,0                 ; clear wrapflag and test pagemode
        jz      t09p                    ; jump pagemode

                                        ; scrollmode:
        mov     ax,cpos
        cmp     ax,1915                 ; test for 'out of bottom'
        jle     t091

tcrlf:  call    consesc                 ; charstring to screen:
        db      13, 10, 10              ; scroll
        mov     ax,23*80                ; new cursor pos.
        mov     cpos,ax
        call    tloc
texit2: jmp     texit                   ; end 'out of bottom'

t091:   mov     bl,80                   ; scrollm, not near the end:
        div     bl
        and     ah,3                    ; this code calculates the new...
        neg     ah
        add     ah,4
        mov     al,ah
        xor     ah,ah
        add     ax,cpos
        mov     cpos,ax                 ; ...cursor position!
        call    tloc                    ; set cursor
        jmp     texit                   ; exit

t09p:   mov     bx,cpos                 ; 'TAB', pagemode:
        inc     bx                      ; this 'inc' is to emulate a bug in
                                        ; RC851.
        cmp     bx,1920                 ; should be '1919' if 'inc' is removed
        jne     t092
        xor     bx,bx                   ; wrap bottom to top of screen
t092:   mov     cpos,bx
                                        ; now search next protected pos.
        mov     ax,ds
        mov     es,ax                   ; ES:=DS
        mov     cx,1920
        sub     cx,bx                   ; CX:=rem. chars to bott. pf screen
        lea     di,prtab[bx]            ; map pointer to DI
t094:   xor     al,al                   ; search key=0 ('protected')

        repne scasb                     ; search protected
        je      t093                    ; jump if found
        mov     cx,cpos                 ; not found: search from top
        lea     di,prtab
        jmp     t094                    ; there MUST be a protected char,
                                        ; or pagemode would not be set
t093:   lea     bx,prtab
        sub     di,bx
        dec     di                      ; new 'pos' in DI
        mov     cpos,di
        mov     bx,di                   ; req. by 'tunpr0'
        call    tunpr0                  ; set cursor at next unprot.
        jmp     texit                   ; end 'TAB'



t10:    xor     al,al                   ; chr(10): 'NL' ----------------------
        xchg    al,wrap                 ; test and clear wrapflag
        or      al,al
        jnz     texit2

        cmp     pagem,0                 ; test for pagemode
        je      t10p
                                        ; scrollmode:
        mov     ax,10
        push    ax
        call    consout                 ; write 'NL' on console
        cmp     cpos,(1920-80-1)        ; are we on bottom line?
        jg      t102                    ; yes: the cursor pos. to be unchanged
        add     cpos,80                 ; no: one line down
        jmp     texit
t102:   mov     ax,10
        push    ax
        call    consout                 ; 'NL' to scroll
        mov     ax,cpos
        call    tloc                    ; cursor up on line 23
        jmp     texit

t10p:   add     cpos,80                 ; pagemode 'NL': one line down
        cmp     cpos,(1920-1)           ; out of bottom?
        jle     t101
        sub     cpos,24*80              ; yes: move to curr. col. on top line
t101:   call    tunpr1
        jmp     texit                   ; position and finish
                                        ; end 'NL'



t12:    mov     wrap,0                  ; clear flags
        mov     pagem,32
        mov     protm,32                ; *** curr. attribute should be reset
        mov     ax,ds
        mov     es,ax                   ; ES:=DS
        lea     di,prtab
        mov     ax,(32*256)+32          ; clear screenmap
        mov     cx,1920/2
        rep stosw

        call    tupdin
        xor     dx,dx                   ; clear scrren and reset attrib.:
        mov     cx,1920
        lea     si,prtab
        call    tupd                    ; direct cons. buf output
        call    tupdfi

        mov     cpos,0
        xor     ax,ax                   ; new pos =0
        call    tloc                    ; set cursor
        jmp     texit
                                        ; end 'CLEAR'



t13:    mov     ax,cpos                 ; chr(13): 'CR' ----------------------
        mov     bl,80
        div     bl                      ; move to col.0, curr. line
        mov     al,ah
        xor     ah,ah
        sub     cpos,ax
        call    tunpr1                  ; move cursor
        jmp     texit                   ; exit
                                        ; end 'CR'



t15:    mov     protm,0                 ; chr(15): 'SET PROTECT' -------------
texit3: jmp     texit                   ; set protectmode and exit
                                        ; *** attribute should be set
                                        ; end 'SET PROTECT'


t24:    mov     bx,offset texit         ; chr(24): 'CURSOR FWD' --------------
        push    bx
        mov     ax,cpos
        inc     ax
        cmp     pagem,0
        jz      t24p                    ; jump if pagemode

        cmp     ax,1920                 ; test for lower right corner
        jne     t242
        jmp     tcrlf                   ; jump to special action
t242:   mov     cpos,ax                 ; save pos.
        jmp     tloc                    ; set cursor and exit

t24p:   cmp     ax,1920                 ; pagemode:
        jne     t241
        xor     ax,ax                   ; wrap bottom to top
t241:   mov     cpos,ax                 ; save pos.
        jmp     tunpr1                  ; set cursor and exit
                                        ; end 'CURSOR FWD'



t26:    cmp     cpos,79                 ; chr(26): 'CURSOR UP' ---------------
        jle     texit3                  ; ignore if on top line
        sub     cpos,80
        call    tunpr1                  ; move cursor
        jmp     texit                   ; exit
                                        ; end 'CURSOR UP'



t27:    mov     tentry,offset t27a      ; chr(27): 'ESC' ---------------------
        jmp     texit                   ; next entry to t27a

t27a:   mov     tentry,offset rc851     ; reset entrypoint
        mov     ax,bx                   ; return value = char
        pop     bp
        ret     2                       ; end 'ESC'



t28:    mov     protm,32                ; chr(28): 'RESET' -------------------
        call    tunpr                   ; move to unprot.
        jmp     texit                   ; *** attrib. should be cleared
                                        ; end 'RESET'



t29:    mov     wrap,0                  ; chr(29): 'HOME'
        mov     cpos,0
        call    tunpr1                  ; move cursor
        jmp     texit                   ; exit
                                        ; end 'HOME'



t31:    call    tupdin                  ; init erase
        mov     cx,1920                 ; chr(31): 'EEOS'
        sub     cx,cpos                 ; no.chrs to CX
        jmp     tera                    ; goto 'erase area'
                                        ; end 'EEOS'

        ; end control char routines



        ; entry table for ctrl char actions:

tctr    dw      texit, texit, texit, texit
        dw      texit, t05,   t06,   t07
        dw      t08,   t09,   t10,   texit
        dw      t12,   t13,   texit, t15
        dw      texit, texit, texit, texit
        dw      texit, texit, texit, texit
        dw      t24,   texit, t26,   t27
        dw      t28,   t29,   t30,   t31




        ; procedure tunpr;
        ; moves the cursor to the next unprotected position.
        ; if protectmode or
        ; if current position is unprotected, no action is taken.
        ;
        ; secondary entries:
        ; tunpr0: perform function even if protectmode. 'pos' must
        ;         be loaded to BX before entering here.
        ; tunpr1: cursor position on console is updated, even if
        ;         'cpos' is not changed


tunpr:  mov     bx,cpos                         ; test protection
        mov     al,byte ptr prtab[bx]
        cmp     protm,al
        jg      tunpr0                          ; return if protectmode or
        ret                                     ; cuur. pos. not protected

tunpr1: mov     bx,cpos
        mov     al,byte ptr prtab[bx]
        cmp     protm,al
        mov     ax,bx
        jle     tloc                            ; goto update from AX

tunpr0: mov     ax,ds
        mov     es,ax                   ; set ES for scas instr.
        mov     cx,1920
        sub     cx,bx                   ; CX:=no.chrs curr.pos.-end of screen
        lea     di,prtab[bx]            ; map pointer to DI
        mov     al,32                   ; search key
        xor     bl,bl                   ; clear overrun flag
tunpr3: or      bl,bl                   ; dummy (label on 'repne' does not work)
        repne scasb                     ; search unprotected ('32' in map)
        je      tunpr2                  ; jump if found

        mov     cx,cpos                 ; not found: search from top to curr.
        lea     di,prtab
        or      bl,bl                   ; test overrun
        mov     bl,1                    ; ...and set flag
        jz      tunpr3                  ; if not overrun goto search
                                        ; falls through here, if all
        lea     di,prtab+1              ; pos. are protected. The cursor is
                                        ; then set at (0,0)

tunpr2: lea     bx,prtab
        sub     di,bx                   ; found: calc. new pos.
        dec     di
        mov     cpos,di
        mov     ax,di

tloc:   mov     bl,80                   ; set cursor position:
        div     bl
tloc1:  mov     dl,ah
        mov     dh,al
        mov     ah,2                    ; subfunc. no.
        xor     bh,bh                   ; pageno.=0
        int     10H                     ; set cursor
        ret



        ; procedure tupdin
        ; must be called to init 'tupd'

tupdin: mov     ah,3
        mov     bh,0
        int     10H             ; get cursor position
        mov     cursave,dx      ; save it
        ret                     ; dummy in this version.



        ; procedure tupd;
        ; replaces direct calls of int-10h function no. 0AH 'update console
        ; buffer'.

tupd:   push    dx                      ; save params
        push    si
        push    cx
        mov     ah,2                    ; first, set the cursor
        mov     bh,0
        int     10H
        pop     cx                      ; restore reg's (in any case...)
        pop     si
        pop     dx
        push    dx
        push    si
        push    cx

        cmp     cx,80                   ; 80 chars max. are updated at one
        jle     tupd1                   ; time to avoid loss of interrupts
        mov     cx,80                   ; in some implementations
tupd1:  mov     al,32                   ; char='sp'
        mov     ah,09H                  ; subfunc.no.
        xor     bh,bh                   ; pageno.
        mov     bl,normatt
        push    cx                      ; save actual no. of chars
        int     10H                     ; update (part of) screen
        mov     ss,sss
        pop     bx
        pop     cx
        pop     si
        pop     dx
        sub     cx,bx                   ; subtract chars outp. from chars wanted
        jcxz    tupdx
        inc     dh                      ; more chars: inc. lineno.
        add     si,80                   ; update src. addr.
        jmp     tupd                    ; repeat
tupdx:  ret                             ; end tupd


                                        ; update area on sattelite:


        ; procedure tupdfi
        ; restore after tupd

tupdfi: mov     dx,cursave              ; restore cursor pos.
        xor     bh,bh
        mov     ah,2
        int     10H
        ret                             ; dummy in this version



rc851   endp



code    ends

        end

