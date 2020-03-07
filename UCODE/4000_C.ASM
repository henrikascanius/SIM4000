;**********************************************************************
;*****
;*****              RC8000 machine instructions, part 12
;*****
;**********************************************************************

        INCLUDE UCHEAD.ASM
        INCLUDE ADDRMACS.ASM

; io, aw

I8259_1Base     EQU     20H
SysTimerBase    EQU     40H
TimeConst8000   EQU   30545  
ConvFactor      EQU     120


;**********************************************************************
;*****
;*****                         Input/Output
;*****
;**********************************************************************
GetTimer MACRO
        sti
        mov     al,0AH
        cli
        out     I8259_1Base,al   ; set Read_IRR mode on 8259
        jmp     $+2
        jmp     $+2
        jmp     $+2
        in      al,I8259_1Base   ; Get IRR
        jmp     $+2
        jmp     $+2
        shl     eax,8
        mov     al,0C2H;
        out     SysTimerBase+3,al; latch counter0 status&count
        jmp     $+2
        jmp     $+2
        jmp     $+2
        in      al,SysTimerBase ; Get status
        jmp     $+2
        jmp     $+2
        jmp     $+2
        shl     eax,8
        in      al,SysTimerBase ; Get LSB(Count)
        jmp     $+2
        jmp     $+2
        jmp     $+2
        shl     eax,8
        in      al,SysTimerBase ; Get MSB(Count)
        jmp     $+2
        jmp     $+2
        jmp     $+2
        xchg    al,ah
        ENDM


_io     MACRO   w
        LOCAL @@1,@@2,@@3,@@4,@@5,@@6

        cmp     eax,es:ClockSense
        je      @@1                     ; jump on sense clock device

        mov     es:EA,eax               ; save Eff. address
        mov     eax,ds:DWORD PTR [&w*4]
        mov     es:Wreg,eax             ; Save Wreg content
        mov     es:ReqKind,0
        mov     es:IC,esi               ; for debuging
   
        int     0F0H
   
        mov     eax,es:Wreg
        mov     ds:DWORD PTR [&w*4],eax
        mov     ch,es:Ex22
        mov     cl,es:Ex23
   
        incic

@@1:    ; Clock sense operation implemented here for performance reasons
        ; You are not supposed to understand this.
        ; (At least not without looking in CLOCK.PAS)

        test    es:FullAccuracy,1
        jz      @@6             ; jump on timeslice-granular clock

        mov     ebx,-1
@@4:
        GetTimer                ; returns w. int disabled, DO NOT ENABLE until end
        sub     bx,ax
        cmp     bx,500
        ja      @@2
        mov     bx,ax
        cmp     eax,ebx
        je      @@3
@@2:    mov     ebx,eax
        jmp     @@4
@@3:
        shl     ebx,8           ; CF=IRR(0)
        setc    ch
        shl     ebx,1           ; CF:=OUT1
        setc    cl
        mov     ebx,TimeConst8000+TimeConst8000
        shr     ebx,cl
        shl     eax,16
        shr     eax,16
        sub     ebx,eax
        shr     ebx,1           ; now, ebx=Cnt8254

        lfs     eax,es:ClockCntP
        mov     eax,fs:[eax]
        test    ch,1
        jz      @@5             ; jump if not timerint. pending
        cmp     ebx,TimeConst8000-100
        jae     @@5
        inc     eax
@@5:
        and     eax,3FH
        shl     eax,8
        xchg    eax,ebx
        xor     edx,edx
        mov     ecx,ConvFactor
        div     ecx
        add     eax,ebx
        shl     eax,8
        sti
        mov     ds:DWORD PTR [&w*4],eax
        xor     ecx,ecx
        
        incic
@@6:
        lfs     eax,es:ClockCntP
        mov     eax,fs:[eax]
        and     eax,3FH
        shl     eax,16
        mov     ds:DWORD PTR [&w*4],eax
        xor     ecx,ecx
        incic

        ENDM


        MakeOp  io,1


;**********************************************************************

_aw     MACRO   w                       ; Autoload Word
        LOCAL   @@1

        mov     es:EA,eax               ; save Eff. address
        mov     eax,ds:DWORD PTR [&w*4]
        mov     es:Wreg,eax             ; Save Wreg content
        mov     es:ReqKind,1
        mov     es:Optional,0
   
        int     0F0H
   
        mov     ch,es:Ex22
        mov     cl,es:Ex23

        test    es:Optional,1
        jnz     @@1
        mov     ebx,es:EA
        mov     eax,es:WReg
        shr     ebx,1
        mov     ds:DWORD PTR [ebx*4],eax ; load into core
@@1:
        incic

        ENDM

        MakeOp  aw,0

Code ENDS
     END Start

