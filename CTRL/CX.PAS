(**********************************************************************)
(* Unit name      : CX.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 96-08-10 17:53   HJ Initial version
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  CX driver for RC4000 simulator
(*
(**********************************************************************)

{$F+}

UNIT CX;


INTERFACE

USES
   Cons;

TYPE

   CXLPSTATETYPE = (READY, HELD, SUM1, SUM2);

   SUBADDRESSTYPE = 1..4;


   (* CX MAIN OBJECT (not a device): *)

   CxMain = OBJECT
      _SubDevices:   ARRAY[SUBADDRESSTYPE] OF CxDeviceP;
      _CurrRxSub:    SUBADDRESSTYPE;
      _CurrTxSub:    SUBADDRESSTYPE;

      



   (* ABSTRACT DEVICE, CX TERMINAL / CX PRINTER: *)

   CxDeviceP = ^CxDevice;

   CxDevice = OBJECT (GenericConsDevice)
      _CxMainP:      CxMainDeviceP;
      _SubAddr:      BYTE;

      TxQueue:       KeyboardQueue;
      TxImmediate:   KeyboardQueue;

      CONSTRUCTOR Init(DevNo: WORD;
                        IoInt,OprInt: BYTE; SubAddr: BYTE);

      PROCEDURE   Wr(Modif: BYTE); VIRTUAL;


   END;

   
   (* CX TERMINAL: *)

   CxTermDeviceP = ^CxTermDevice;
   CxTermDevice = OBJECT (CxDevice)
      _Error:        BOOLEAN;
      _PollFlag:     BOOLEAN;
   END,


   (* CX PRINTER: *)

   CxPrintDeviceP = ^CxPrintDevice;
   CxPrintDevice = OBJECT (CxDevice)
      _Checksum:     BYTE;
      _State:        CXLPSTATETYPE;
   END;





IMPLEMENTATION

(**********************************************************************)
(* Proc. Name     : CxDevice.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR CxDevice.Init(DevNo: WORD;
                          IoInt,OprInt: BYTE; SubAddr: BYTE);

BEGIN
  INHERITED Init(DevNo,IoInt,OprInt);
  TxQueue.Init;
  TxImmediate.Init;
  _SubAddr := SubAddr;
  _CxMainP := NIL;
END; (* CxDevice.Init *)





(**********************************************************************)
(* Proc. Name     : CxDevice.Wr
(* Function       : 
(**********************************************************************)
PROCEDURE CxDevice.Wr (Modif: BYTE);

BEGIN
   IF TxQueue.IsFull THEN
   WITH State8000 DO
   BEGIN
      Ex22 := 0;
      Ex23 := 1;
   END ELSE
   BEGIN
      IF Modif = WRITE_PROMPT
         THEN _Status := Ord(_Prompt)
         ELSE _Status := (State8000.SrvcParam.Wreg SHR 8) AND $7F;
      IF _Status<>0 THEN WriteChar(Chr(_Status));
      WITH State8000 DO
      BEGIN
         IF TxQueue.IsFull
            THEN _WrIntrPending := TRUE
            ELSE IR := IR OR (LONGINT(1) SHL (31-_IoInt));
         Ex22 := 0;
         Ex23 := 0;
      END;

      IF _Busy THEN Timer.CancelTimeout;
      _InpEnabled := FALSE;
      _Busy := FALSE;
   END;
END; (* CxDevice.Wr *)


(**********************************************************************)
(*****              UNIT ENTRY AND EXIT PROCEDURES
(**********************************************************************)

VAR

   ExitSave  : pointer;

(**********************************************************************)
(* Proc. Name     : UnitExit
(* Function       : Exit procedure.
(**********************************************************************)
PROCEDURE UnitExit;

BEGIN
   Exitproc := ExitSave;
END; (* UnitExit *)




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
END. (* UNIT CX *)

