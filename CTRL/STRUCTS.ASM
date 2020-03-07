;**********************************************************************
;*****
;***** DefineData structure definitions for RC8000 simulator
;*****
;**********************************************************************

;**********************************************************************
;*****
;*****                    V86 virtual stack image
;*****
;**********************************************************************

v86def  STRUC
__stack db      (256-44) DUP (0) ; Stack space for VCPI server
ret32   dd      0,0     ; Return address from call, not used
ip86    dw      0
        dw      0
cs86    dw      0
        dw      0
eflg86  dd      0
sp86    dw      0
        dw      0
ss86    dw      0
        dw      0
es86    dw      0
        dw      0
ds86    dw      0
        dw      0
fs86    dw      0
        dw      0
gs86    dw      0
        dw      0
v86def  ENDS


;**********************************************************************
;*****
;*****             FWORD ptr, 32-bit offset and selector
;*****
;**********************************************************************

FWPtr   STRUC
Offs    dd      0
Select  dw      0
        ENDS

;**********************************************************************
;*****
;*****                  Protected mode entry block
;*****
;**********************************************************************

PMEntDef STRUC
PMCR3   DD      0
PMGDTR  DD      0
PMIDTR  DD      0
PMLDTR  DW      0
PMTR    DW      0
PMEIP   DD      0
PMCS    DW      0
        ENDS
        

;**********************************************************************
;*****
;*****        Param. record for copy betw. V86 and PM memory
;*****
;**********************************************************************

CopyRec STRUC
V86Seg  DW      0
V86Ref  DD      0        
Words   DW      0
PMSeg   DW      0
Addr    DD      0
        ENDS

INCLUDE S8.ASM
