        INCLUDE UCHEAD.ASM
        INCLUDE ADDRMACI.ASM
;**********************************************************************
;*****
;*****                 Auxiliary routines for RC4000:
;*****
;**********************************************************************




        InsPoint run_p
;run:                                   ; Entry point for _Run8000
        mov     eax,[esi]
        BreakAtFetch                    ; Always test for interrupts after
                                        ; 1st instruction
        mov     dr7,ebx                 ; set breakpoint AFTER 1st fetch
        xor     edi,edi                 ; edi[31..16] must always be 0

        rol     eax,12

        mov     di,ax
        sar     eax,12                  ; place D-field as operand in EAX
        jmp     cs:DWORD PTR Optable[edi*4]
                                        ; jump thru cs, NOT gs; we don't
                                        ; want a break before 1st instruction

        InsPoint BadOp_p

;BadOpCode:                             ; All GP faults also ends here...
                                        ; (assumed to be address violations)
        or      S8.IR,80000000H         ; Set instr. exception
        breakatfetch
        incic


        InsPoint Break_p
;Break8000:
        mov     eax,S8.IR
        bt      eax,31                  ; test instr. exception
        jc      _Int                    ; (cannot be disabled)

        test    es:S8.IntEn,1
        jz      _NoInt

_Int:
        and     eax,S8.IM
        jz      _NoInt

        ; *********** MAKE RC4000 INTERRUPT: ************
        cli
                                        ; avoid trig of breakpoints while 
        mov     ebx,dr7                 ; modifying core
        push    ebx
        xor     ebx,ebx
        mov     dr7,ebx                 
        bsr     eax,eax                 ; get bit no.
        btr     S8.IR,eax               ; clear bit in IR
        btr     WORD PTR S8.IntEn,0     ; Int. disable
        sub     al,31
        neg     al
        shl     eax,9                   ; 2*intno ready to save
        mov     DS:DWORD PTR [16],eax   ; intno. to core[8]

        shl     esi,7
        mov     DS:DWORD PTR [20],esi   ; return addr. to core[10]

        mov     esi,DS:DWORD PTR [24]   ; service address in core[12]
        sar     esi,9
        shl     esi,2

        pop     ebx
        mov     dr7,ebx
        sti
_NoInt:  
        cmp     S8.NextScreen,0FFH      ; Handle virt. screen switch
        jne     _Br
        mov     al,S8.Trace
        or      al,S8.Stop
        jnz     _Br
        mov     ax,cs
        mov     gs,ax
        FetchNext
        
_Br:
        int     1
        FetchNext



Code ENDS
     END Start
