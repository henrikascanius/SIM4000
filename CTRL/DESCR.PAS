(*#LEFT 6*)(*#TITLE ""*)

(**********************************************************************)
(* Unit name      : DESCR.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 92-05-10 21:11   HJ Initial version
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  Descriptor definition unit for SIM4000.
(*
(**********************************************************************)

{$F+}

UNIT DESCR;


INTERFACE

CONST
   TSSSize     = 104;   (* Size of a Task State Segment *)

TYPE

   HugePtr     =  LONGINT;

   MemSegType  =  (READONLY,READWRITE,UNSED2,READONLYEXPDN,EXECONLY,
                   EXECREAD,EXECONLYCONF,EXECREADCONF);

   SysGateType =  (UNUSED0,TSS286,LDT,BUSYTSS286,CALLGATE286,TASKGATE,
                   INTGATE286,TRAPGATE286,UNUSED8,TSS386,UNUSED10,BUSYTSS386,
                   CALLGATE386,UNUSED13,INTGATE386,TRAPGATE386);

   ProtLevel   =  0..3;                   

   TSSType     =  ARRAY [0..TSSSize-1] OF BYTE;

   Descr386 =
   OBJECT
      _LoPart  :  LONGINT;
      _HiPart  :  LONGINT;

      PROCEDURE Init(S: BOOLEAN);
      PROCEDURE Done;
      FUNCTION  IsSystemDescr : BOOLEAN;
      FUNCTION  IsMemDescr    : BOOLEAN;
      FUNCTION  IsGateDescr   : BOOLEAN;
      FUNCTION  BaseAddr : HugePtr; 
      PROCEDURE SetBaseAddr(Addr: HugePtr);
      FUNCTION  Limit : LONGINT;
      PROCEDURE SetLimit(Lim: LONGINT);
      PROCEDURE ShowDescr (Name: STRING);
   END;

   MemDescr =
   OBJECT (Descr386)
      PROCEDURE Init(SegType: MemSegType; DPL: ProtLevel;
                       PageGran, Big, Present : BOOLEAN);
   END;

   SysDescr =
   OBJECT (Descr386)
      PROCEDURE Init(DescrType: SysGateType; DPL: ProtLevel;
                       PageGran, Present : BOOLEAN);
   END;

   GateDescr =
   OBJECT (Descr386)
      PROCEDURE Init(DescrType: SysGateType; DPL: ProtLevel;
                     Present : BOOLEAN);
      FUNCTION  DWCount: BYTE;
      PROCEDURE SetDWCount(C: BYTE);
      FUNCTION  Selector: WORD;
      PROCEDURE SetSelector(S: WORD);
      FUNCTION  Offset: HugePtr;
      PROCEDURE SetOffset(O: HugePtr);
   END;



(*#PAGE*)
IMPLEMENTATION

USES
   OpString;

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : Descr386.Init
(* Function       : 
(**********************************************************************)
PROCEDURE Descr386.Init (S: BOOLEAN);

BEGIN
   _HiPart := Ord(S) SHL 12;
   _LoPart := 0;
END; (* Descr386.Init *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : Descr386.Done
(* Function       : 
(**********************************************************************)
PROCEDURE Descr386.Done;

BEGIN
END; (* Done *)

(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : Descr386.IsSystemDescr
(* Function       : 
(**********************************************************************)
FUNCTION Descr386.IsSystemDescr: BOOLEAN;

BEGIN
   IsSystemDescr := (_HiPart SHR 8) AND $f IN [1,2,3,9,11];
END; (* Descr386.IsSystemDescr *)

(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : Descr386.IsMemDescr
(* Function       : 
(**********************************************************************)
FUNCTION Descr386.IsMemDescr: BOOLEAN;

BEGIN
   IsMemDescr := ((_HiPart SHR 12) AND $1) = 1;
END; (* Descr386.IsMemDescr *)

(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : Descr386.IsGateDescr
(* Function       : 
(**********************************************************************)
FUNCTION Descr386.IsGateDescr: BOOLEAN;

BEGIN
   IsGateDescr := (_HiPart SHR 8) AND $f IN [4,5,6,7,12,14,15];
END; (* Descr386.IsGateDescr *)

(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : Descr386.BaseAddr
(* Function       : 
(**********************************************************************)
FUNCTION Descr386.BaseAddr: HugePtr;

BEGIN
   BaseAddr := (_LoPart SHR 16) + ((_HiPart AND $ff) SHL 16) +
               (_HiPart AND $ff000000);
END; (* Descr386.BaseAddr *)

(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : Descr386.SetBaseAddr
(* Function       : 
(**********************************************************************)
PROCEDURE Descr386.SetBaseAddr(Addr: HugePtr);

BEGIN
   _LoPart := (_LoPart AND $ffff) + (Addr SHL 16);
   _HiPart := (_HiPart AND $00ffff00) +
              ((Addr SHR 16) AND $ff) +
               (Addr AND $ff000000);
END; (* Descr386.SetBaseAddr *)

(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : Descr386.Limit
(* Function       : 
(**********************************************************************)
FUNCTION Descr386.Limit: LONGINT;

BEGIN
   Limit := (_LoPart AND $ffff) + (_HiPart AND $000f0000);
END; (* Descr386.Limit *)

(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : Descr386.SetLimit
(* Function       : 
(**********************************************************************)
PROCEDURE Descr386.SetLimit(Lim: LONGINT);

BEGIN
   _LoPart := (_LoPart AND $ffff0000) + (Lim AND $ffff);
   _HiPart := (_HiPart AND $fff0ffff) +
              (Lim AND $000f0000);
END; (* Descr386.SetLimit *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : MemDescr.Init
(* Function       : 
(**********************************************************************)
PROCEDURE MemDescr.Init(SegType: MemSegType; DPL: ProtLevel;
                          PageGran, Big, Present : BOOLEAN);

BEGIN
   Descr386.Init(TRUE);
   _HiPart := _HiPart + Ord(SegType) SHL 9;
   _HiPart := _HiPart + DPL SHL 13;
   IF PageGran THEN _HiPart := _HiPart + $00800000;
   IF Big      THEN _HiPart := _HiPart + $00400000;
   IF Present  THEN _HiPart := _HiPart + $00008000;
END; (* MemDescr.Init *)


(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : SysDescr.Init
(* Function       : 
(**********************************************************************)
PROCEDURE SysDescr.Init(DescrType: SysGateType; DPL: ProtLevel;
                          PageGran, Present : BOOLEAN);

BEGIN
   Descr386.Init(FALSE);
   _HiPart := _HiPart + Ord(DescrType) SHL 8;
   _HiPart := _HiPart + DPL SHL 13;
   IF PageGran THEN _HiPart := _HiPart + $00800000;
   IF Present  THEN _HiPart := _HiPart + $00008000;
END; (* SysDescr.Init *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : GateDescr.Init
(* Function       : 
(**********************************************************************)
PROCEDURE GateDescr.Init(DescrType: SysGateType; DPL: ProtLevel;
                         Present : BOOLEAN);

BEGIN
   Descr386.Init(FALSE);
   _HiPart := _HiPart + Ord(DescrType) SHL 8;
   _HiPart := _HiPart + DPL SHL 13;
   IF Present  THEN _HiPart := _HiPart + $00008000;
END; (* GateDescr.Init *)
(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : GateDescr.DWCount
(* Function       : 
(**********************************************************************)
FUNCTION GateDescr.DWCount: BYTE;

BEGIN
   DWCount := _HiPart AND $1f;
END; (* GateDescr.DWCount *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : GateDescr.SetDWCount
(* Function       : 
(**********************************************************************)
PROCEDURE GateDescr.SetDWCount(C: BYTE);

BEGIN
   _HiPart := (_HiPart AND $FFFFFFE0) + (C AND $1F);
END; (* GateDescr.SetDWCount *)

(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : GateDescr.Selector
(* Function       : 
(**********************************************************************)
FUNCTION GateDescr.Selector: WORD;

BEGIN
   Selector := (_LoPart SHR 16);
END; (* GateDescr.Selector *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : GateDescr.SetSelector
(* Function       : 
(**********************************************************************)
PROCEDURE GateDescr.SetSelector (S: WORD);

BEGIN
   _LoPart := (_LoPart AND $FFFF) + (LONGINT(S) SHL 16);
END; (* GateDescr.SetSelector *)

(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : GateDescr.Offset
(* Function       : 
(**********************************************************************)
FUNCTION GateDescr.Offset: HugePtr;

BEGIN
   Offset := (_LoPart AND $FFFF) + (_HiPart AND $FFFF0000);
END; (* GateDescr.Offset *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : GateDescr.SetOffset
(* Function       : 
(**********************************************************************)
PROCEDURE GateDescr.SetOffset (O: HugePtr);

BEGIN
   _LoPart := (_LoPart AND $FFFF0000) + (O AND $FFFF);
   _HiPart := (_HiPart AND $FFFF) + (O AND $FFFF0000);
END; (* GateDescr.SetOffset *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : Descr386.ShowDescr
(* Function       : Writes contents of descriptor on CRT. FoOr debugging.
(**********************************************************************)
PROCEDURE Descr386.ShowDescr (Name: STRING);

VAR L: LONGINT;
    S: STRING;

BEGIN
   IF (_HiPart AND $1000) <> 0 THEN
   BEGIN  (* S=1, Memory descr *)
      CASE (_HiPart SHR 9) AND 7 OF
         0: S := 'RO   ';
         1: S := 'RW   ';
         2: S := '*****';
         3: S := 'RW ED';
         4: S := 'EX   ';
         5: S := 'RE   ';
         6: S := 'EX CO';
         7: S := 'RE CO';
      END;
      L := (_HiPart AND $FF000000) + ((_HiPart AND $FF) SHL 16) +
           ((_LoPart AND $FFFF0000) SHR 16);
      Write(Pad(Name,12),Pad(S,5),': Base=$',HexL(L),' ',L:9);

      L := (_HiPart AND $000F0000) + (_LoPart AND $FFFF);
      Write(' Limit=$',HexL(L),' ',L:7);

      Write(' DPL=',(_HiPart SHR 5) AND 3,' ');
      IF (_HiPart AND $00800000) <>0 THEN
         Write('G ');
      IF (_HiPart AND $00400000) <>0 THEN
         Write('B ');
      IF (_HiPart AND $00200000) <>0 THEN
         Write('? ');
      IF (_HiPart AND $00100000) <>0 THEN
         Write('AVL ');
      IF (_HiPart AND $00001000) <>0 THEN
         Write('A ');
      WriteLn;
   END ELSE WriteLn(Name:10,': SysDescr');

END; (* ShowDescr *)



(*#CPAGE 20*)
(**********************************************************************)
(*****              UNIT ENTRY AND EXIT PROCEDURES
(**********************************************************************)

VAR

   ExitSave  : pointer;

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : UnitExit
(* Function       : Exit procedure.
(**********************************************************************)
PROCEDURE UnitExit;

BEGIN
   Exitproc := ExitSave;
END; (* UnitExit *)




(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : UnitEntry
(* Function       : Entry procedure for unit.
(**********************************************************************)
PROCEDURE UnitEntry;

BEGIN
   Exitsave := Exitproc;
   Exitproc := @UnitExit;
END; (* UnitEntry *)



BEGIN
   UnitEntry;
END. (* UNIT DESCR *)

