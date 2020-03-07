;**********************************************************************
;*****
;*****              RC8000 SIMULATOR FOR 80386/80486
;*****
;*****      Designed and programmed by Henrik Jacobsen  1992.
;*****
;*****
;*****  UCHEAD.ASM : Common frame for the RC8000 code interpreter modules.
;*****               (Prev. RC8000.ASM)
;**********************************************************************
;***** Change history:
;***** 94-11-15 00:54 HJ Code reorganised
;***** 94-11-13 23:09 HJ Obsolete code removed(fetch, afteramfetch); 
;*****               
;*****                          
;*****
;**********************************************************************

        MASM 
        .386P
        .387

        INCLUDE MAKEMAC.ASM
        INCLUDE OPUTIL.ASM
        INCLUDE ..\CTRL\S8.ASM
        INCLUDE ..\CTRL\SELECT.ASM

Data    SEGMENT USE32
Data    ENDS

Stck    SEGMENT USE16
Stck    ENDS

;**********************************************************************
;*****
;*****  Define segment for access to State8000 from protected mode
;*****
;**********************************************************************


STATE   SEGMENT USE16

        ORG     0
S8      LABEL State8000Rec   

STATE   ENDS


Code    SEGMENT USE32
        ASSUME CS:Code,DS: Data, ES: STATE, SS: Stck



;**********************************************************************
;*
;*               MAP OF CODE SEGMENT WHEN LOADED:
;*
;*      0h : Optable
;*   4000h : Table of pointers to misc. entry points (defined in UCODEREF.INC)
;*   UC1st : Start of code
;*
;* Each module (part) has its own opcode table for the instructions
;* defined in that module.
;*
;* All entries in the table area are word-sized during assembly.
;*
;*
;**********************************************************************




Optable         EQU     0
run_p           EQU     2000H
BadOp_p         EQU     2002H
Break_p         EQU     2004H
UC1st           EQU     2006H


        ORG 100h                ; Required to make a .COM file

Start:
        db      (UC1st-Optable) dup (0)    ; Init. entry point table


Addr    =       $

; assume DI[31..16] is 0!!!


