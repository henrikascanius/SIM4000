;**********************************************************************
;*****
;*****   Define selectors. Must match declarations in PASCAL code.
;*****
;**********************************************************************




LDT          EQU  1  * 8;
VCPICS       EQU  2  * 8;
VCPIDS       EQU  5  * 8;
CoreSeg      EQU  6  * 8;
TSSDescr     EQU  7  * 8;
PascData     EQU  8  * 8;
PascStack    EQU  9  * 8;
SCode        EQU 10  * 8;
SCodeD       EQU 11  * 8;
ICode        EQU 12  * 8;
PMStack      EQU 13  * 8;
State8Seg    EQU 14  * 8;
PMIStack     EQU 15  * 8;
BreakSeg     EQU 16  * 8;
