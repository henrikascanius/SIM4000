;**********************************************************************
;*****
;*****                       State8000 record
;*****
;**********************************************************************

State8000Rec STRUC
IC              DD      0
IM              DD      0
IR              DD      0
Brp             DD      0
Ex23            DB      0
Ex22            DB      0
Ex21            DB      0
IntEn           DB      0
RstKey          DB      0
AldKey          DB      0
Step            DB      0
Trace           DB      0
Stop            DB      0
ResetSys        DB      0
ResetMode       DB      0
Running         DB      0
ClockSense      DD      0
ClockCntP       DF      0
FullAccuracy    DB      0
NextScreen      DB      0
; SrvcParam part:

ReqKind         DB      0
WReg            DD      0
EA              DD      0
Optional        DD     8 DUP (0)
             ENDS


